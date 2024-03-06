---
layout: post
title: Host Homepage inside a Alpine LXC
description: A tutorial to set up the Homepage project for Alpine Linux from scratch
tags:
- Home Lab
- Self-hosted
- Proxmox
- Homepage
---
# Host Homepage inside a Alpine LXC

[Homepage][homepage] is a customizable "home page" or "dashboard" that you can
host yourself. I have to say the name of the project is really bad. It is very
hard to google it, since the vast majority of "homepage" hints will not be this
repo.

![screenshot][screenshot_readme]

Screenshot from the README in the official repo.

Again I will cite the [repo](pve_helper) that hosts many excellent scripts,
including one for homepage. However, it only supports a Debian LXC as the host,
which, I think, is completely overkill for this case. As a result, I decide to
deploy it on Alpine myself.

## Alpine LXC

Setting up an Alpine LXC is trivial, so I will not touch any details here.
However, I will give an overview on the amount of resources needed in different
cases.

{:class="table table-bordered"}
|      | Alpine (Building) |  Alpine | Debian |
|------|:-----------------:|:-------:|:------:|
| CPU  |         2         |    1    |    1   |
| RAM  |       > 1 GB      |  256 MB | 256 MB |
| Disk |        1 GB       |   1 GB  |  2 GB  |

Building Homepage from source can max out 2 virtual cores for both OSes.
However, giving the LXC more cores do not seem to matter. For example, giving 4
cores to the container, PVE shows max CPU usage is about 50%. I would say just
give it 2 cores whenever you set up Homepage for the first time or upgrading.
Running the server essentially needs 0 computational power, so just giving it 1
core after building is done.

For RAM, I notice a max RAM usage of about 1 GB when building the package. Note
that if the LXC is running out of RAM, the building speed will be severely
bottlenecked. So make sure you give the container enough RAM when setting the
package up. Personally, I give it 2 GB. When the server is up, my Alpine
container uses about 125 MB RAM and Debian surely needs a little more (about 215
MB for my case). Either way, 256 MB should be plenty for hosting.

For disk, the OS of Debian alone requires a lot more space. My installation
currently is sitting at 1.6 GB, while Alpine is using less than 500 MB. 1 GB
should be more than sufficient for Alpine.

## Building Homepage

Here I will directly borrow some codes from [tteck's script][pve_helper].

### Download latest release

I once used the git repo as the source and built upon it, but it turned out to
be rather tedious. At least in the old time, the devs did not exclude all files
resulted from building, so it was a huge pain to clean up the working tree just
to `git pull`. So just download the release tarballs.

Assuming we are setting up for the first time.

```shell
RELEASE=$(curl -s https://api.github.com/repos/gethomepage/homepage/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q https://github.com/gethomepage/homepage/archive/refs/tags/v${RELEASE}.tar.gz
tar -xzf v${RELEASE}.tar.gz
cp -r homepage-${RELEASE} /opt/homepage
rm -rf homepage-${RELEASE} v${RELEASE}.tar.gz
```

Next we need install `npm` and optionally `pnpm` as recommended by the Homepage
devs

```shell
apk add npm
apk add pnpm --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing
```

If you want to install pnpm from Alpine's package manager, make sure use the
"testing" branch from the "edge" repo. This is currently the only available
`pnpm` from `apk`.

Next build Homepage

```shell
cd /opt/homepage
pnpx update-browserslist-db@latest
pnpm install
pnpm build
```

Now everything should be fine. Running `pnpm start` and you should see the page
at `http://lxc_ip:3000`.

### Autostart the node server

If you are doing this on Debian, a systemd configuration file will be
automatically created and enabled. You do not have to worry about it. However,
for Alpine, we have to create the `init.d` script ourselves.

Let us create a file called `/etc/init.d/homepage`. Depending on whether you opt
for `npm` or `pnpm`, the file can be slightly different. For example, with
`pnpm`, we will have

```shell
#!/sbin/openrc-run

name=homepage
description="Homepage server"
pidfile=/var/run/homepage.pid
command=/usr/bin/pnpm
command_background="yes"
output_log=/var/log/homepage/output.log
error_log=/var/log/homepage/error.log
work_dir=/opt/homepage

depend() {
    need net
}

start_pre() {
    checkpath --directory --owner root:root --mode 0775 $work_dir /var/log/homepage
}

start() {
    start-stop-daemon --start \
        --exec "$command" \
        --pidfile "$pidfile" \
        --make-pidfile \
        --background \
        -- \
        -C "$work_dir" start
}

stop() {
    start-stop-daemon --stop \
        --pidfile "$pidfile"
}

status() {
    if [ -f /var/run/homepage.pid ]; then
        echo "Homepage server is running"
    else
        echo "Homepage server is not running"
    fi
}
```

With the help of [OpenRC][openrc], it is now much easier to handle the script.
We are basically using `openrc-run` to call `start-stop-daemon`, which in turn
will run the node server as a daemon. As starting the Homepage server is `pnpm
start`, but there is no corresponding "stop" commend. Apart from killing `node`
directly, one better solution is to create a "PID file" for the daemon, and then
you can use `start-stop-daemon --stop --pidfile "$pidfile"` to stop the daemon.
Here I am using `/var/run/homepage.pid`. `status` is just a quick way to tell if
the service is already running by checking the PID file. Additionally, with this
OpenRC approach, you no longer need to use a switch in the script.

You might have noticed the `-C $work_dir start` line. This is how you serve a
node package from another directory with `pnpm`. The full command line is `pnpm
-C /opt/homepage start`. However, if you use `npm`, the corresponding command
should be `npm start --prefix /opt/homepage`. Notice the difference and you
should change the `command` and argument line accordingly for `npm`.

Now we can do 

```shell
# to start
/etc/init.d/homepage start
# or
service homepage start
# to stop
/etc/init.d/homepage stop
# or
service homepage stop
# to check status
/etc/init.d/homepage status
# or
service homepage status
```

`systemctl` by default will not work here, as Alpine does not use systemd.

The last step, we should add this item to startup, which can be done through

```shell
rc-update add homepage default
```

After reboot, you should see the Homepage server automatically starts. If you
run `rc-status` now, you should see

```console
homepage:~# rc-status
Runlevel: default
 networking                                 [  started  ]
 homepage                                   [  started  ]
 crond                                      [  started  ]
 sshd                                       [  started  ]
Dynamic Runlevel: hotplugged
Dynamic Runlevel: needed/wanted
 localmount                                 [  started  ]
Dynamic Runlevel: manual
```

You can start customize your homepage now!

[homepage]: https://github.com/gethomepage/homepage
[pve_helper]: https://tteck.github.io/Proxmox/
[openrc]: https://github.com/OpenRC/openrc
[screenshot_readme]: https://github.com/gethomepage/homepage/blob/main/images/1.png?raw=true