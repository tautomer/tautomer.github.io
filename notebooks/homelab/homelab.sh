#!/usr/bin/env bash

set -eu

layout="post"
subdir="blog/homelad"

../notebook_convert.py \
    --nbpath npm_reverse_proxy.ipynb \
    --date "2024-02-24" \
    --layout ${layout} \
    --subdir ${subdir} \
    --description "A tutorial to use AdGuard Home and Nginx Proxy Manager to certify self-hosted services and access them without the need of port numbers" \
    --tags "Home Lab" "Networking" "Self-hosted" "Proxmox" "OpenWrt" "Nextcloud"