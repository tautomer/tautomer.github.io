#!/usr/bin/env bash

set -eu

layout="post"
subdir="blog/ml"

../notebook_convert.py \
    --nbpath protein_protein_interaction_p1.ipynb \
    --date "2024-02-25" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "Use a convolutional neural network to predict if a pairs of proteins interact with each other, part 1." \
    --tags "Machine Learning" "Neural Network" "Coding" "Python" "Torch"

../notebook_convert.py \
    --nbpath protein_protein_interaction_p2.ipynb \
    --date "2024-03-06" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "Use a convolutional neural network to predict if a pairs of proteins interact with each other, part 2." \
    --tags "Machine Learning" "Neural Network" "Coding" "Python" "Torch"

../notebook_convert.py \
    --nbpath protein_protein_interaction_p3.ipynb \
    --date "2024-03-08" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "Use a convolutional neural network to predict if a pairs of proteins interact with each other, part 3." \
    --tags "Machine Learning" "Neural Network" "Coding" "Python" "Torch"
