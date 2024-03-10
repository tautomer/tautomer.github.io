---
layout: post_markdown
title: Host Grafana and Prometheus inside a Alpine LXC
description: A tutorial to install and run Grafana and Prometheus on Alpine
tags:
- Home Lab
- Self-hosted
- Proxmox
- Sysadmin
- Devops
---
# Host Grafana and Prometheus inside a Alpine LXC

[Grafana][grafana] is nice dashboard tool to visualize a dataset interactively,
but collecting external data is not so easy with Grafana. As a result, Grafana
is often paired with [Prometheus][prometheus], which is specialized in data
collection.

We will set up both tools inside an Alpine LXC.

## Set up

First, we will create a new Alpine LXC. To summarize, we will give it 2 cores, 1
GB RAM, 1 GB disk. Later, after everything is installed, we will only assign 1
core and 255 MB RAM to the LXC. At this moment, my setup only consumes about 160
MB RAM and nearly 0 usage on CPU.

### Install Grafana and Prometheus

Fortunately, both packages are available through Alpine's package manager `apk`.
You can install them through

```shell
apk add grafana prometheus 
```

or newer versions from the Edge repo

```shell
apk add grafana prometheus --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
```

### Configure the services

Even though both packages are packaged and maintained. For some unknown reasons,
both the configuration files in `/etc` do not work! I have no idea behind the
decision to ship half-done configuration files with the packages, considering
the installation is the same on all these Alpine systems.

To make both services actually work, we have to make some changes. I did not
know what was needed, so I checked out the their Alpine docker images. Here are
the links to these files which might help you as well if you decide to do some
customizations.

[Dockerfile for Grafana][grafana_docker]

[run.sh for grafana][grafana_run]

[Dockerfile for Prometheus][prometheus_docker]

Long story short, `/etc/init.d/grafana` should be like this

```shell
#!/sbin/openrc-run

supervisor=supervise-daemon

name="Grafana"
description="Metrics Dashboard and Graph Editor"

GF_PATHS_CONFIG="/etc/grafana.ini"
GF_PATHS_DATA="/var/lib/grafana/data"
GF_PATHS_HOME="/usr/share/grafana"
GF_PATHS_LOGS="/var/log/grafana"
GF_PATHS_PLUGINS="/var/lib/grafana/plugins"
GF_PATHS_PROVISIONING="/var/lib/grafana/provisioning"
GRAFANA_OPTS="--config=$GF_PATHS_CONFIG \
              --homepath=$GF_PATHS_HOME \
              --packaging=apk \
              cfg:default.paths.data=$GF_PATHS_DATA \
              cfg:default.paths.logs=$GF_PATHS_LOGS \
              cfg:default.paths.plugins=$GF_PATHS_PLUGINS \
              cfg:default.paths.provisioning=$GF_PATHS_PROVISIONING"


command="/usr/bin/grafana"
command_args="server $GRAFANA_OPTS"

command_user=grafana:grafana

depend() {
        need net
        after firewall
}

start_pre() {
        checkpath -d -o grafana:grafana -m755 $GF_PATHS_HOME \
        $GF_PATHS_LOGS \
        $GF_PATHS_DATA \
        $GF_PATHS_PLUGINS \
                $GF_PATHS_PROVISIONING \
                $GF_PATHS_PROVISIONING/alerting \
                $GF_PATHS_PROVISIONING/dashboards \
                $GF_PATHS_PROVISIONING/datasources \
                $GF_PATHS_PROVISIONING/notifiers \
                $GF_PATHS_PROVISIONING/plugins
}
```

All these `GF_PATHS` environment variables useful to start Grafana's server, and
some are actually necessary. The server will not run with them, like `--config`
and `--homepath`. Among all these directories, only the log path does not
already exist, but as far as I know, `checkpath` in `start_pre` will take care
it.

Similarly, we will fix the script for Prometheus, which is
`/etc/init.d/prometheus`

```shell
#!/sbin/openrc-run
name="prometheus"

description="prometheus monitoring system & time series database"
supervisor=supervise-daemon
# env
prometheus_config_file="/etc/prometheus/prometheus.yml"
prometheus_storage_path="/var/lib/prometheus"
prometheus_log_path="/var/log/prometheus"
prometheus_console_lib="/etc/prometheus/console_libraries"
prometheus_console_temp="/etc/prometheus/consoles"
prometheus_retention_time="1y"

command=/usr/bin/prometheus
command_args="--config.file=$prometheus_config_file \
        --storage.tsdb.path=$prometheus_storage_path \
        --storage.tsdb.retention.time=$prometheus_retention_time \
        --web.console.templates=/etc/prometheus/consoles \
        --web.console.libraries=/etc/prometheus/console_libraries \
        $prometheus_args"
command_user="prometheus:prometheus"
extra_started_commands="reload"

# prometheus need to open a lot chunks
rc_ulimit="${prometheus_ulimit:--n 65536}"

start_pre() {
        checkpath -d -m 755 -o prometheus:prometheus $prometheus_storage_path \
        $prometheus_log_path
        [ -n "$output_log" ] && checkpath -f "$output_log" \
                -m 644 -o prometheus:prometheus
        [ -n "$error_log" ] && checkpath -f "$error_log" \
                -m 644 -o prometheus:prometheus
}

reload() {
        ebegin "Reloading ${RC_SVCNAME}"
        supervise-daemon ${RC_SVCNAME} --signal HUP
        eend $?
}
```

Again, all files ana paths, except `/var/log/prometheus`, are already shipped
with the package.

Now you should be able to successfully run both packages with

```shell
# to start
/etc/init.d/grafana start
/etc/init.d/prometheus start
# or
service grafana start
service prometheus start
```

If both commands run successfully, you should be able to access Prometheus at
`http://host_ip:9090` and Grafana at `http://host_ip:3000`. Then the last step
will be to start both services at startup

```shell
rc-update add grafana
rc-update add prometheus
```

Additionally, if you want to make some changes, like deleting a dataset, through
Prometheus' HTTP API, add the following line to your init.d file

```ini
prometheus_args="--web.enable-admin-api"
```

Then you can perform some administrating stuff though POST, for example,

```shell
curl -XPOST -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={job="job_name"}'
```

to delete a job named "job_name" with curl.

[grafana]: https://grafana.com/oss/grafana/
[prometheus]: https://prometheus.io/
[grafana_docker]: https://github.com/grafana/grafana/blob/main/Dockerfile
[grafana_run]: https://github.com/grafana/grafana/blob/main/packaging/docker/run.sh
[prometheus_docker]: https://github.com/badtuxx/prometheus_alpine/blob/master/Dockerfile