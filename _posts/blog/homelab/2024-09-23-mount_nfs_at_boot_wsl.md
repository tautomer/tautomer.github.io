---
layout: post_markdown
title: Mounting an NFS Drive at Boot in WSL
description: WSL fails to mount a NFS drive defined in /etc/fstab. Here is an easy fix.
tags:
- Home Lab
- Sysadmin
---
# Mounting an NFS Drive at Boot in WSL

The following is the `/etc/fstab` file I use in a Debian VM to mount a NFS drive
from my NAS at boot, which works flawlessly.

```ini
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
deepdarkfantasy.lan:/volume2/photo /mnt/photos nfs auto,nofail,vers=4.1,noatime,nolock,tcp,actimeo=1800 0 0
```

However, when I copy this configuration to my Ubuntu WSL, it does not work
anymore. To be more precise, the `mount -a` run by the system during boot fails
and returns an error of,

```text
Processing fstab with mount -a failed
```

which does not provide any information. After WSL boots up, you can manually run
`sudo mount -a`, which works perfectly fine. An easy guess would be that for
whatever reason, the network part is not fully initialized when the system is
running `mount -a`. I do not know why this happens or how to fix it on the
system level (there might be some relevant issues on GitHub though), but here is
the fix.

## The fix

To solve this problem, we just have to remove the line from `/etc/fstab` and run
it at startup after network is online.

### `/etc/wsl.conf` approach

`/etc/wsl.conf` has a `[boot]` section to host the commands you want to run
during startup. We can simply solve the problem by adding the following line to
the configuration

```ini
[boot]
command = "mount -t nfs -o vers=4.1,noatime,nolock,tcp,actimeo=1800 deepdarkfantasy.lan:/volume2/photo /mnt/photo"
```

Basically just copy the mount command there. I do not know why this would work,
but it just does the job.

### A note on `systemd`

On a normal Linux installation, you can use the `network-online.target` in
`systemd` to force a service only to run after the network connection is ready.
While the current WSL2 already supports `systemd` (see details
[here][systemd_wsl]), `systemd-networkd-wait-online.service` does not really
work. It gets stuck in "activating" status, such that services depend on it will
not run.

[systemd_wsl]: https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/#set-the-systemd-flag-set-in-your-wsl-distro-settings