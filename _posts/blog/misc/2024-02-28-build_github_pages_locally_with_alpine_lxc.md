---
layout: post
title: Build GitHub Pages locally with Jekyll on Alpine
description: The workflow is the largely the same with what is on WSL, but with some Alpine specific things and LXC settings.
tags:
- Home Lab
- Self-hosted
- Coding
- OS
- DIY
---
# Build GitHub Pages locally with Jekyll on a Alpine LXC

When I was trying to build this site locally, my first attempt was on an Alpine
LXC. If you think about hosting a simple site, running it in a simple docker
image just works. However，all my docker containers are running inside a Debian
VM inside Proxmox, and I already have more than 10 containers there. To add some
redundancy, I decided to install Jekyll in an Alpine LXC.

## Set up the Alpine LXC

To add an Alpine LXC, we can again borrow [this convenient script][script]. You
can pretty much use the default options. Just two things to note.

1. When installing Ruby packages and building the site, the system may need
   several hundred MB RAM, so I increased the assigned RAM size to 1 GB.
2. Alpine installation is really compact, so I only gave it 1 GB virtual HD, but
   it turns out that the repo alone is several MB. With installing Alpine and
   Ruby packages, the whole LXC quickly took up almost 800 MB on the disk, so I
   increased the virtual disk to 2 GB.

## Install packages

To use Jekyll, here are the thing you will need

```shell
apk update
# to build jejyll
apk add ruby ruby-dev libffi-dev alpine-sdk
gem install bundle 
```

Since we are using the root user of the LXC anyway, you do not need `sudo` or
`--user-install` options. Then you just have to clone your repo, run `bundle
install`, and serve your site with `bundle exec jekyll serve --host=0.0.0.0
--incremental --livereload`. Note the option `--host=0.0.0.0` is needed if you
want to access the page from LAN (and you will).

On the other hand, if you only want to serve the site locally not developing,
using `nginx` can save a lot of RAM. In my case, the who LXC only uses less than
15 MB RAM.

You just have to install `nginx` via

```shell
apk add nginx
```

Create a configuration file, like `/etc/nginx/http.d/github-pages.conf`. Below
is an example configuration

```nginx
server {
    listen       80;
    server_name jekyll.lan;
    root /var/www/github-pages;
    index  index.html;
    # log files
    access_log  /var/log/nginx/gh_access.log;
    error_log   /var/log/nginx/gh_error.log;
}
```

Then disable the default page and start `nginx`

```shell
mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.disable
# start nginx service
service nginx start
# start nginx when the sytstem boots up
rc-update add nginx default
```

[script]: https://github.com/tteck/Proxmox/blob/main/install/alpine-install.sh
