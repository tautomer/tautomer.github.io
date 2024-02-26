#!/usr/bin/env bash

set -eu

layout="post"
subdir="blog/ml"

../notebook_convert.py \
    --nbpath protein_protein_interaction.ipynb \
    --date "2024-02-25" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "Use a neural network to predict if a pairs of proteins interact with each other" \
    --tags "Machine Learning" "Neural Network" "Coding" "Python" "Torch"
