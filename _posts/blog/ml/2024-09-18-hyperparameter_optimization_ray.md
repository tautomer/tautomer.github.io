---
layout: post_markdown
title: Distributed asynchronous parallelized hyperparameter optimization with Ray
description: Hyperparameter optimization is crucial for obtaining an accurate neural network. Typically, this is done through a Bayesian optimization by running a set of trials sequentially. With Ray and Ax, however, we can distribute the optimization across all allocated resources. This approach significantly reduces the wall time required for completing these tasks.
tags:
- Machine Learning
- Neural Network
- Coding
- Python
- Torch
---
# Distributed asynchronous parallelized hyperparameter optimization with Ray

This post is largely based on the tutorial I wrote for our hippynn package,
which can be found [here][example]. This workflow has been an important part of
my research work at LANL on a physics-informed neural network (PINN) for excited
state properties, which was published in [JCTC][jctc] earlier this year. The
example introduced both Ax sequential optimization and a parallel version with
Ray. In this post, we will instead only focus on the Ray part.

Hyperparameter optimization is crucial for obtaining an accurate neural network.
Unfortunately, finding the optimal parameters is quite often not so intuitive
for us humans. As a result, automatic optimization is numerically very helpful.
One popular way to achieve this is so-called Bayesian optimization. In this
framework, with a user-defined parameter range, a set of trials is generated.
Based on certain metrics returned from the trials, new parameters will be
generated to minimize/maximize the metrics. In this post, I will show you how to
efficiently distribute a Bayesian optimization task onto different GPUs or nodes
simultaneously with Ray and Ax. This is especially useful if you have a
relatively small network, but multiple GPUs available on a node, where it does
not make sense to use multiple GPUs for one model, making sequential trials a
waste of resources. 

## Set up the environment

The packages required to perform this task are [Ax][ax] and [Ray][ray].

```shell
conda install -c conda-forge "ray < 2.7.0"
pip install ax-platform!=0.4.1
```

> A few things to note:
> 
> 1. The scripts have been tested with `ax-platform 0.4.0` and `ray 2.6.3`, and
>    many previous versions of the two packages.
> 2. Unfortunately, several changes made in recent versions of `ray` will break
>    this script. You should install `ray < 2.7.0`. If you know how to make the
>    scripts work with the latest Ray package, please let me know.
> 3. `pip install` is recommended by the Ax developers even if a conda
>    environment is used.
> 4. As of now (Sep 2024), `ax-platform 0.4.1` is broken. See the [issue][issue]
>    here. Please avoid this version in your setup.

## Create the optimization workflow

The relevant codes can be found [here][codes]. There are 4 files in the
directories, copied from the `hippynn` repo.

> A quick "README":
> 1. `process_QM7_data.py` is to convert the QM7 dataset to the format for
>    `hippynn`.
> 2. `QM7_ax_example.py` is the actual training script.
> 3. `ax_opt_ray.py` is the script for the optimization.
> 4. `parameters.json` is an example input file to set the parameter range for
>    the optimization.

I will then walk you through the codes.

### Define the target function

> **Note**: even though I am using a `hippynn` training script as an example,
> this workflow is general. Any function that takes certain input values and
> returns a certain output can be used as the target function to obtain the
> optimal inputs that minimize or maximize the output.

I will not touch too much detail on `hippynn` and skip the technical details in
the `QM7_ax_example.py` script. Here is the key part of the target function:

```python
def training(dist_soft_min, dist_soft_max, dist_hard_max):
    # Log the output of python to `training_log.txt`
    with hippynn.tools.log_terminal("training_log.txt", "wt"):

        # Hyperparameters for the network

        network_params = {
            "possible_species": [0, 1, 6, 7, 8, 16],  # Z values of the elements
            "n_features": 10,  # Number of neurons at each layer
            "n_sensitivities": 10,  # Number of sensitivity functions in an interaction layer
            "dist_soft_min": dist_soft_min,  #
            "dist_soft_max": dist_soft_max,
            "dist_hard_max": dist_hard_max,
            "n_interaction_layers": 1,  # Number of interaction blocks
            "n_atom_layers": 1,  # Number of atom layers in an interaction block
        }
    
        ...

        # Parameters describing the training procedure.
        from hippynn.experiment import setup_and_train

        metric_tracker = setup_and_train(
            training_modules=training_modules,
            database=database,
            setup_params=experiment_params,
        )

        return metric_tracker.best_metric_values
```

This function takes 3 input parameters `dist_soft_min`, `dist_soft_max`,
`dist_hard_max`. They are the key cutoff distances needed by the `hippynn`
network. We then pass these values to a dictionary (called `network_params`) and
use this dictionary to set up the model. After some complicated procedures
(replaced by "..."), we can train the model and get the return metrics (called 
`metric_tracker`). At the end of the target function, this object is returned.

### Ray/Ax script

This script is a lot more complicated. I will explain the main components here.


#### For SLURM

This block is optional but could be very useful for running this script on HPC
(which is most likely the case). Just like a shell script, a Python script can
directly be submitted to the job scheduler as well. The beginning of the script
is actually for SLURM.

```python
#!/usr/bin/env python3
# fmt: off
#SBATCH --time=4-00:00:00
#SBATCH --nodes=1
#SBATCH --mail-type=all
#SBATCH -p gpu 
#SBATCH -J parallel_hyperopt
#SBATCH --qos=long
#SBATCH -o run.log
# black always format pure comments as of now
# add some codes here to keep SLURM derivatives valid
import json
import os
import sys
import warnings

# SLURM copies the script to a tmp folder
# so to find the local package `training` we need add cwd to path
# per https://stackoverflow.com/a/39574373/7066315
sys.path.append(os.getcwd())
# fmt: on
```

1. `# fmt: off` and `# fmt: on` are used to tell `black` to not format this
   block. Otherwise, `black` will automatically add a space between "#" and
   "SBATCH", causing these commands to unrecognizable for SLURM. However, this
   derivative does not work if the block has pure comments, so I had to add some
   imports here to make it not "pure comments".

2. You might have noticed the line `sys.path.append(os.getcwd())`. As the SO
   question shows, if your target function is a "local import", i.e., sitting in
   a separate file (not within a package) and imported to the Ray script,
   running the script in SLURM will cause an import error. The solution is to
   add the `cwd` (current working directory) to PATH.

#### Imports

Then we will import the rest of the required packages.

```python
import shutil

import numpy as np
import ray
from ax.core import Trial as AXTrial
from ax.service.ax_client import AxClient
from ax.service.utils.instantiation import ObjectiveProperties
from QM7_ax_example import training
from ray import air, tune
from ray.air import session
from ray.tune.experiment.trial import Trial
from ray.tune.logger import JsonLoggerCallback, LoggerCallback
from ray.tune.search import ConcurrencyLimiter
from ray.tune.search.ax import AxSearch

# to make sure ray loads correct the local package
ray.init(runtime_env={"working_dir": "."})
```

1. Note that the target function `training` is locally imported from
   `QM7_ax_example`.
2. While `sys.path.append(os.getcwd())` is needed to find the local import file
   with SLURM, `ray.init(runtime_env={"working_dir": "."})` serves the same
   purpose, but for `Ray`. Without this line, Ray will NOT be able to import the
   `training` function.

#### Wrap the training function for Ray + Ax

We need to wrap the training function once again so that it can be used for Ray
and Ax.

```python
def evaluate(parameters: dict, checkpoint_dir=None):
    """
    Evaluate a trial for QM7

    Args:
        parameter (dict): Python dictionary for trial values of HIPNN hyperparameters.
        checkpoint_dir (str, optional): To enable checkpoints for ray. Defaults to None.

    Returns:
        dict : Loss metrics to be minimized.
    """

    out = training(**parameters)

    session.report({"Metric": out["valid"]["Loss"]})
```

1. The object returned from the training function is a dictionary, containing
   many different metrics. We might want to do some mathematical expressions on
   these metrics or have some freedom in choosing the metrics without the need
   to directly modify the training function.

2. To correctly return the metric to Ray, we need the line
   `session.report({"Metric": out["valid"]["Loss"]})`. One key thing to note is
   that in the returned dictionary `{"Metric": out["valid"]["Loss"]}`, the key
   "Metric" has to match whatever is defined in the Ax experiment. This will be
   clearer when we go through the codes to create an Ax experiment in Section
   [Create an experiment](#create-an-experiment).

3. Ray will handle the working directory for each trial, so do NOT do this
   yourself in either `training` or `evaluate`. Just leave this to Ray.

This function `evaluate` will be the actual target function for our
optimization.

#### Ray callbacks

This part is rather complicated, and I do not want to go through the details,
either. Just to briefly summarize, this piece of code is responsible for,

1. Saving the Ax experiment status after each trial,
2. Additional handling of failed trials, especially the ones that do not raise
   an error but result in a NaN or inf output, which are effectively failed
   trials,
3. Calculate elapsed time for each trial.

For most cases, copying & pasting this snippet into your Ray script should be
enough.

```python
class AxLogger(LoggerCallback):
    def __init__(self, ax_client: AxClient, json_name: str, csv_name: str):
        """
        A logger callback to save the progress to json file after every trial ends.
        Similar to running `ax_client.save_to_json_file` every iteration in sequential
        searches.

        Args:
            ax_client (AxClient): ax client to save
            json_name (str): name for the json file. Append a path if you want to save the \
                json file to somewhere other than cwd.
            csv_name (str): name for the csv file. Append a path if you want to save the \
                csv file to somewhere other than cwd.
        """
        self.ax_client = ax_client
        self.json = json_name
        self.csv = csv_name

    def log_trial_end(
        self, trial: Trial, id: int, metric: float, runtime: int, failed: bool = False
    ):
        self.ax_client.save_to_json_file(filepath=self.json)
        shutil.copy(self.json, f"{trial.local_dir}/{self.json}")
        try:
            data_frame = self.ax_client.get_trials_data_frame().sort_values("Metric")
            data_frame.to_csv(self.csv, header=True)
        except KeyError:
            pass
        shutil.copy(self.csv, f"{trial.local_dir}/{self.csv}")
        if failed:
            status = "failed"
        else:
            status = "finished"
        print(
            f"AX trial {id} {status}. Final loss: {metric}. Time taken"
            f" {runtime} seconds. Location directory: {trial.local_path}."
        )

    def on_trial_error(self, iteration: int, trials: list[Trial], trial: Trial, **info):
        id = int(trial.experiment_tag.split("_")[0]) - 1
        ax_trial = self.ax_client.get_trial(id)
        ax_trial.mark_abandoned(reason="Error encountered")
        self.log_trial_end(
            trial, id + 1, "not available", self.calculate_runtime(ax_trial), True
        )

    def on_trial_complete(
        self, iteration: int, trials: list["Trial"], trial: Trial, **info
    ):
        # trial.trial_id is the random id generated by ray, not ax
        # the default experiment_tag starts with ax' trial index
        # but this workaround is totally fragile, as users can
        # customize the tag or folder name
        id = int(trial.experiment_tag.split("_")[0]) - 1
        ax_trial = self.ax_client.get_trial(id)
        failed = False
        try:
            loss = ax_trial.objective_mean
        except ValueError:
            failed = True
            loss = "not available"
        else:
            if np.isnan(loss) or np.isinf(loss):
                failed = True
                loss = "not available"
        if failed:
            ax_trial.mark_failed()
        self.log_trial_end(
            trial, id + 1, loss, self.calculate_runtime(ax_trial), failed
        )

    @classmethod
    def calculate_runtime(cls, trial: AXTrial):
        delta = trial.time_completed - trial.time_run_started
        return int(delta.total_seconds())
```

#### Initialize the search space

The following code will initialize a basic search space for an Ax experiment. I
made it possible that the parameters can either be directly provided inside the
script or from a json file passed as an argument to the script. The second way
is very handy if the script is under version control and you do not want to get
diffs because of modifying the search space.

```python
# initialize the client and experiment.
if __name__ == "__main__":

    warnings.warn(
        "\nMake sure to modify the dataset path in QM7_ax_example.py before running this example.\n"
        "For this test (Ray parallelized optimization), you MUST provide an absolute path to the dataset."
    )

    if len(sys.argv) == 2:
        with open(sys.argv[1], "r") as param:
            parameters = json.load(param)
    else:
        parameters = [
            {
                "name": "dist_soft_min",
                "type": "range",
                "value_type": "float",
                "bounds": [0.5, 1.5],
            },
            {
                "name": "dist_soft_max",
                "type": "range",
                "value_type": "float",
                "bounds": [3.0, 20.0],
            },
            {
                "name": "dist_hard_max",
                "type": "range",
                "value_type": "float",
                "bounds": [5.0, 40.0],
            },
        ]
```

The search space for Ax is a list of dictionaries with each parameter having its
own dictionary. Commonly, the dictionary can have these keys,

```python
{
    "name": "dist_hard_max",
    "type": "range",
    "value_type": "float",
    "log_scale": True,
    "bounds": [5.0, 40.0],
}
```

1. `name` is the name for the variable, which should correspond to an input
   variable of the target function.
2. `type` has three valid choices, `fixed` (one fixed value), `range` (a list of
   two elements corresponding to the lower and upper bounds), and `choice` (a
   list of possible choices).
3. `value_type` is the data type of the value, which can be omitted. However,
   sometimes you want to control the datatype if an integer should be used.
4. `log_scale` is an optional variable to switch Ax's parameter-generating
   strategy from linear to log.
5. The last key can be `value` for `fixed` or `bounds` for `range` and
   `choices`, where the actual search space is provided here.

#### Create/restart/extend an Ax experiment

In this section, we create or reload an experiment. Note that for an already
finished experiment, it is possible to reload it, and increase the total
number of trials, which will effectively extend the experiment. The newly added
trials will have parameters generated from the inherited history of the previous
experiment.

```python
if restart:
    ax_client = AxClient.load_from_json_file(filepath="hyperopt_ray.json")
    # update existing experiment
    # `immutable_search_space_and_opt_config` has to be False
    # when the experiment was created
    ax_client.set_search_space(parameters)
else:
    ax_client = AxClient(
        verbose_logging=False,
        enforce_sequential_optimization=False,
    )
    ax_client.create_experiment(
        name="QM7_ray_opt",
        parameters=parameters,
        objectives={
            "Metric": ObjectiveProperties(minimize=True),
        },
        overwrite_existing_experiment=True,
        is_test=False,
        # slightly more overhead
        # but make it possible to adjust the experiment setups
        immutable_search_space_and_opt_config=False,
        parameter_constraints=[
            "dist_soft_min <= dist_soft_max",
            "dist_soft_max <= dist_hard_max",
        ],
    )
```

##### Create an experiment

Let us take a look at the `else` branch first. To create an Ax experiment, first
initialize an empty `AxClient` object. Here it is important to set
`enforce_sequential_optimization` to false so that we can parallelize the
trials. Next, we will fill in some details.

1. `name` is pretty much self-explanatory.
2. `parameters` is the search space we have defined/read previously.
3. `objectives` is a dictionary for the goals of this experiment.
   1. The dictionary keys, for example, `Metric` here, **MUST** match the keys
      in the dictionary returned from `session.report` in your target function.
   2. `ObjectiveProperties` defines whether you want to minimize
      (`minimize=True`) or maximize (`minimize=False`) the metric. This class
      also has an argument called `threshold`. If a threshold is given and the
      returned metric is beyond the threshold, Ax will not use this trial when
      generating the next trial.
   3. I would recommend only using one objective here. If you have multiple
      metrics to be optimized, do a mathematical expression when the target
      function wrapper is defined and pass that variable to `session.report`.

You can provide some basic constraints to the search space through
`parameter_constraints`. It is a list of strings. In each string, you can
provide a conditional between two parameters. Note that a conditional containing
mathematical expressions will not work, for example, "dist_soft_max <= 2 *
dist_hard_max".

`immutable_search_space_and_opt_config` will make it possible to modify the
settings of the experiment after the experiment is created. This is especially
useful if you want to restart or extend the experiment.

##### Restart/extend an experiment

Restarting an experiment or adding additional trials to an experiment shares the
same workflow. The key is the JSON file saved from the callback functions. An
experiment state can be restored using

```python
ax_client = AxClient.load_from_json_file(filepath="hyperopt_ray.json")
```

where the JSON file contains everything about this experiment til the moment the
file is saved. If `immutable_search_space_and_opt_config` is set to false, you
can also alter the settings, for example, the search space, after reloading.

To extend the experiment, simply set the `num_samples` to the desired value in
the following Ray section.

Note that due to the complexity of handling the individual trial path with Ray,
it is not possible to restart unfinished trials at this moment.

#### Ray interface

Then we will use the Ax interface in Ray to perform the optimization. We first
create an interface and set a limit to the number of parallelized jobs. The
callback is also initialized to save the progress and summary.

```python
# run the optimization Loop.
algo = AxSearch(ax_client=ax_client)
algo = ConcurrencyLimiter(algo, max_concurrent=4)
ax_logger = AxLogger(ax_client, "hyperopt_ray.json", "hyperopt.csv")
tuner = tune.Tuner(
    tune.with_resources(evaluate, resources={"gpu": 1}),
    tune_config=tune.TuneConfig(search_alg=algo, num_samples=8),
    run_config=air.RunConfig(
        local_dir="test_ray",
        verbose=0,
        callbacks=[ax_logger, JsonLoggerCallback()],
        log_to_file=True,
    ),
)
tuner.fit()
```

For the `ray.tune.Tuner` class, two variables can be useful. One is the total
number of trials `num_samples`. The other is the `local_dir` variable. The files
will be saved into `./{local_dir}/{trial_function_name}_{timestamp}` where the
progress file `hyperopt_ray.json` and summary `hyperopt.csv` will be saved. Each
trial will have its own subfolder named
`{trial_function_name}_{random_id}_{index}_{truncated_parameters}`. You do not
have to handle the working directory in your target function. In fact, you
should NOT do that. Just leave it to Ray.

Finally, running `tuner.fit()` will automatically distribute the tasks to the
resources you have collected.

[example]: https://lanl.github.io/hippynn/examples/hyperopt.html
[jctc]: https://pubs.acs.org/doi/abs/10.1021/acs.jctc.3c01068
[ray]: https://docs.ray.io/en/latest/
[ax]: https://github.com/facebook/Ax
[issue]: https://github.com/facebook/Ax/issues/2711
[codes]: /assets/codes/hyperparameter_optimization