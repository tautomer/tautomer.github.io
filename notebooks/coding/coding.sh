#!/usr/bin/env bash

set -eu

layout="post"
subdir="blog/coding"

../notebook_convert.py \
    --nbpath broadcasting.ipynb \
    --date "2025-08-26" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "A numerical bug from broadcasting in my algorithm went unnoticed for weeks caused by a wrong call of squeeze(). Instead of an element-wise addition, the operation was silently broadcasted, producing an incorrect but programmatically valid result. The bug was only discovered when an edge case with a zero-valued tensor made the output obviously incorrect... Luckily, I caught it before it is too later." \
    --tags "Machine Learning" "Coding" "Python" "Torch"