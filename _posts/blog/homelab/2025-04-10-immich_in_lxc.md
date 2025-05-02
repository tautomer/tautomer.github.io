---
layout: post_markdown
title: Hosting immich in LXC with iGPU passthrough
description: A guide for directly hosting immich inside an LXC. In this way, you do not have to run immich inside a docker container which is in turn inside a VM or privileged LXC. As a bonus point, you can pass through iGPU to multiple LXCs such that you can enjoy accelerations for some ML and transcoding tasks within LXC. Additionally, I wrote a GitHub workflow routinely (or manually) checking new immich release and building the new server with GitHub's runner, which can save lots of efforts on your side.
tags:
- Home Lab
- Self-hosted
- immich
- LXC
- Sysadmin
- Devops
---
# Host immich in LXC with iGPU passthrough

After trying several self-hosted photo services, I finally settled down with
[immich][immich github]. While it is quick and easy to set up immich with
docker, I have always been trying to run it directly inside an LXC. The main
reason is hardware acceleration. You can run docker inside a privileged LXC
(which is discouraged) or a VM. Correct me if I am wrong, but if you pass the
GPU to the VM, you can no longer pass it to other LXCs, which is apparently a
deal breaker. Thanks to the hard work by GitHub user [loeeeee][loeeeee], which
largely formed the foundation of this post.

## Install

`loeeeee` have already developed a good writeup on how to set up the LXC, so
here I will simply add a few things that could mess up or be improved.

### Python version on Ubuntu

As of now, Ubuntu LTS (24.04) is shipped with Python 3.12 by default. For
hardware acceleration with you iGPU, you need the
[openvino package][openvino github] from Intel. At this moment, immich only
supports `onnxruntime-openvino=0.18.0`. As you can see from
[pypi][openvino pypi], this version is only built for Python 3.11. This means
you either install Python 3.11 yourself for immich or build the wheel yourself
for Python 3.12. Apparently, the first approach is more cost effective.

On a my daily driver, I would definitely use `conda` to manage Python versions,
but it just seems to be too much hassle for a server. I decided to install
Python though `apt`.

The following commands expects you to run in `root` and you likely will.

```shell
add-apt-repository ppa:deadsnakes/ppa
apt update
apt install python3.11 python3.11-venv python3.11-dev
ln -sf /usr/bin/python3.11 /usr/bin/python3
```

Note that we are overwriting the default Python version of the system to make
our life easier. This change will be reverted back later.

### Vector extension for PostgreSQL

loeeeee's README ask you to install the `pgvector` extension through `apt`.
While this will work fine, there are two problems.

1. `immich v1.102` introduced the vector stuff in the database. The dev team
   chose to go with `pgvecto.rs` which is incompatible with `pgvector`. As such,
   if you migrate existing database, you will see some confusing and misleading
   error messages from `PostgreSQL`, like this

2. The developers of `pgvecto.rs` claim their version is more performant over
   `pgvector`. As I am not a database person, I cannot comment on this, but it
   might be better to use this one instead.

At this moment, `immich` use the version `0.3.0` of this extension, so please do
not download the latest one. Simple download the deb for your PostgreSQL
version, install it with `dpkg -i`, and then enabling the extension in your
current database.

For example, for PostgreSQL 14

```shell
wget https://github.com/tensorchord/pgvecto.rs/releases/download/v0.3.0/vectors-pg14_0.3.0_amd64.deb
dpkg -i vectors-pg14_0.3.0_amd64.deb
```

Then connect to database `immich` using user postgres with
`sudo -u postgres psql immich` and run the following command,

```sql
DROP EXTENSION IF EXISTS vectors;
CREATE EXTENSION vectors;
```

Note that `pgvecto.rs` currently only supports PostgreSQL 14-17. Make sure you
install a compatible version. as the current `immich` official docker image uses
PostgreSQL 14, I am going with this one.

### GPU passthrough

There are lots of posts online regarding this part. In short, this process
requires bind mounting of devices related to the iGPU and [id mapping][mapping].
However, I did struggle a lot initially when doing the id mapping stuff, so I
guess it does not hurt to have one more post to explain this.

```conf
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.idmap: u 0 100000 65536
lxc.idmap: g 0 100000 43
lxc.idmap: g 44 44 1
lxc.idmap: g 45 100045 55
lxc.idmap: g 100 100 1
lxc.idmap: g 101 100101 892
lxc.idmap: g 993 103 1
lxc.idmap: g 994 100994 64541
```

```
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:syslog
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
dip:x:30:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
shadow:x:42:
utmp:x:43:
video:x:44:root,immich
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
systemd-journal:x:999:
systemd-network:x:998:
systemd-timesync:x:997:
input:x:996:
sgx:x:995:
kvm:x:994:
render:x:993:root,immich
messagebus:x:101:
syslog:x:102:
ssl-cert:x:103:postgres
systemd-resolve:x:992:
_ssh:x:104:
postfix:x:105:
postdrop:x:106:
uuidd:x:107:
crontab:x:991:
rdma:x:108:
tcpdump:x:109:
polkitd:x:990:
immich:x:1000:
redis:x:110:
postgres:x:111:
```

## Build the server automatically with GitHub Actions

It is such a pain to manually update the server every time when a new immich
version is released. 

[immich github]: https://github.com/immich-app/immich
[loeeeee]: https://github.com/loeeeee/immich-in-lxc
[openvino github]: https://github.com/openvinotoolkit/openvino
[openvino pypi]: https://pypi.org/project/onnxruntime-openvino/1.18.0/#files
[mapping]: https://forum.proxmox.com/threads/understanding-lxc-uid-mappings.101855/