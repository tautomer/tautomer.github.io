---
layout: post_markdown
title: Monitor Nextcloud server with Prometheus and Grafana 
description: A tutorial to export stats from Nextcloud's server to Prometheus and Grafana
tags:
- Home Lab
- Self-hosted
- Nextcloud
- Sysadmin
- Devops
---
# Monitor Nextcloud server with Prometheus and Grafana

1. [Set up the exporters](#set-up-the-exporters)
   1. [node\_exporter](#node_exporter)
   2. [nextcloud-exporter](#nextcloud-exporter)
2. [Prometheus](#prometheus)
3. [Add the dashboard to Grafana](#add-the-dashboard-to-grafana)
   1. [If you unfortunately pasted the original json and want to fix it manually...](#if-you-unfortunately-pasted-the-original-json-and-want-to-fix-it-manually)

In our previous [post][host_grafana_prometheus], we have talked about how to set
up Grafana and Prometheus in an Alpine LXC. To make them actually useful, we
need feed them some real-world data. Here I will use them to monitor the status
of my self-hosted Nextcloud.

![dashboard](/images//homelab/grafana/dashboard.png)

## Set up the exporters

Prometheus can only reads data sources that it understands. To put it in another
way, if a data source is not specifically designed from Prometheus, it needs to
be processed by an "exporter", then Prometheus can import the data. As a result,
we need to set up two exporters. One is called `node_exporter` that sends the
status of the host machine, and the other is `nextcloud-exporter` that reads
Nextcloud's json API and convert it to Prometheus' format.

In principle, `nextcloud-exporter` can be run from anywhere that can access the
Nextcloud server, but the `node_exporter` has to be run from the host of
Nextcloud. For simplicity, we will run both exporters on the host of Nextcloud.
For my case, the Nextcloud is running inside a Debian LXC, so the services are
managed by `systemd`.

### node_exporter

The pre-compiled binary file of the `node_exporter` can be directly downloaded
from its [GitHub release page][node_exporter]. Just find the one that matches
your architecture, download the tarball, extract it, and copy the executable to
a location in your `PATH`. Personally, I copied it to `/usr/local/bin`.

Now, if you run `node_exporter` directly, you should be able to see some
information printed out. Head over to your browser, you should be able to see
some numbers at `http://nextcloud_ip:9100/metrics`. of course, you can also use
`wget` or `curl` to test this. This means `node_exporter` is running ok.

Next, we will set it up as a service.

1. Create a user and group to run `node_exporter`.

   ```shell
   groupadd node_exporter
   useradd -g node_exporter --no-create-home --shell /bin/false node_exporter
   mkdir /etc/node_exporter
   chown node_exporter:node_exporter /etc/node_exporter
   ```

   The configuration file of `node_exporter` will sit in the folder
   `/etc/node_exporter`, but at this moment, we will leave it at default. In the
   future, you can use a configuration file to apply some control on what
   numbers will be exported.

2. Create a file `/etc/systemd/system/node_exporter.service` and paste the
   following content to it 

   ```ini
   [Unit]
   Description=Node Exporter
   Documentation=https://prometheus.io/docs/guides/node-exporter/
   Wants=network-online.target
   After=network-online.target
   [Service]
   Type=simple
   User=node_exporter
   Group=node_exporter
   Restart=always
   ExecStart=/usr/local/bin/node_exporter
   [Install]
   WantedBy=multi-user.target
   ```

   The file is pretty simple. We just want this service to start after the
   system is online. After all, without Internet (at least LAN), where do you
   send the data to?

3. You should be able to run the service without an error
   
   ```shell
   systemctl daemon-reload
   systemctl start node_exporter
   systemctl status node_exporter
   ```

   Everything should look right. If so, add this service to startup via
   `systemctl enable node_exporter`.

Now we are done with `node_exporter`. Let us do the same thing for
`nextcloud-exporter`.

### nextcloud-exporter

For the package to access Nextcloud's `serverinfo` API, authentication is
required. In this case, using a token will be preferred. To set up a token, you
can follow the package's [README][readme].

Next, we need to compile the package

```shell
git clone https://github.com/xperimental/nextcloud-exporter.git
cd nextcloud-exporter
make
```

The package is written in Go, so you need set it up. Follow the official
instruction [here][go]. Just note that the package uses a feature that was added
in version 1.21, so make sure you install a Go version 1.21+.

You will also need `make` and `git`. Both can be installed from the system's
package manager. If just download the zip of the repo, `git` is not necessary.

After the compilation is done, you can run the command via

```shell
nextcloud-exporter -s nextcloud_ip --auth-token your_token
```

This time, you should see the exported numbers at
`http://nextcloud_ip:9205/metrics`. Similar to what we have done previously, we
will add `nextcloud-exporter into services.

1. Create a user and group.

   ```shell
   groupadd nextcloud_exporter
   useradd -g nextcloud_exporter --no-create-home --shell /bin/false node_exporter
   ```

2. Create a file `/etc/systemd/system/nextcloud-exporter.service` and paste the
   following content to it 

   ```ini
   [Unit]
   Description=Nextcloud Exporter
   Documentation=https://github.com/xperimental/nextcloud-exporter
   Wants=network-online.target nginx.service php8.2-fpm.service
   After=network-online.target nginx.service php8.2-fpm.service
   [Service]
   Type=simple
   User=nextcloud_exporter
   Group=nextcloud_exporter
   Restart=always
   ExecStart=/usr/local/bin/nextcloud-exporter \
       -s nextcloud_ip --auth-token=your_token
   [Install]
   WantedBy=multi-user.target
   ```

   Apart from the "online" target, I listed nginx and php-fpm as additional
   dependencies, as Nextcloud will not run without these two services. However,
   it is really not required at all in the systemd file.

3. If the service runs at it should, we can enable it and add it to startup.
   
   ```shell
   systemctl daemon-reload
   systemctl start node_exporter
   systemctl enable node_exporter
   ```

## Prometheus

Next, we will add both exporters to Prometheus. Head to your Prometheus server
and modify the configuration file `/etc/prometheus/prometheus.yml`.

At the end of file, add the following section

```yml
  - job_name: "nextcloud"

    static_configs:
      - targets: ["nextcloud_ip:9205"]
      - targets: ["nextcloud_ip:9100"]
```

to add both exporter to Prometheus. Note that if you have assigned a different
port for either exporter, make sure it matches here.

If you restart your Prometheus service, you should be able to see the new
dataset listed as `nextcloud`

![prometheus](/images/homelab/grafana/prometheus_dataset.png)

## Add the dashboard to Grafana

Now we head to grafana. Add a new data source of our Prometheus server.

![data](/images/homelab/grafana/grafana_data.png)

Then just give a name and URL to your Prometheus. For my case, it is simply
`http://localhost:9090`.

![data_source](/images/homelab/grafana/prometheus_data_source.png)

Next, we can build a dashboard from the data. To save us some efforts, I will
directly import the existing dashboard from [ncp-monitoring-dashboard][ncp]. The
json file to the dashboard is [here][ncp_json].

However, if the dashboard is imported directly, there will be a bunch of error,
because missing matching data source.

![import](/images/homelab/grafana/imported.png)

Of course, you can do this way, and fix everything manually, but there is much
better way. We just have to replace the ID of the data source in the json file.

1. Let us go to `Data sources` > `Prometheus`. Note the ID in the address bar of
   the browser.

   ![id](/images/homelab/grafana/id.png)

    See the selected string? That is the UID of this Prometheus data source.

2. Globally replace the existing UID `P3791F55F620A72A5` with our own's. You can
   do this with any editor.

   ![replace](/images/homelab/grafana/replace.png)

3. Paste the modified json to Grafana. To do this, go to `Dashboards` >
   `New` > `Import`. Now you should only see a warning, not errors.

4. As for the warning about the deprecated `Angular plugin`, just simply switch
   the visualization type from legacy `Graph(old)` to `Time series` or other
   types that work for you.

   ![angular](/images/homelab/grafana/angular.png)

After this step, you should be able to see a dashboard nicely displayed.

![dashboard](/images//homelab/grafana/dashboard.png)

You can start customizing the dashboard for your own needs from here, which
should be much easier than starting from scratch.

### If you unfortunately pasted the original json and want to fix it manually...  

Take a look at the following section if really want to do it manually. However,
my suggestion will be simply delete the dashboard and redo it with the way
described above.

1. These red exclamation symbols are because of mismatching data source. 

   ![legacy](/images/homelab/grafana/legacy.png)

2. Go to a certain panel, and click "Edit"

   ![edit](/images/homelab/grafana/edit.png)

3. Cut whatever exists in the `Metric browser` box, and paste it, then the 
   `Run queries` button will be clickable. Click the button and the data should
   be visualized. Save and apply, and repeat this for all dashboards. For
   dashboards with multiple queries, cutting and pasting for any one of them
   should be enough.

   ![query](/images/homelab/grafana/query.png)

4. Once you have replaced all data sources, this error should be gone.

5. Fixing the "angular` deprecate warning is the same.

[host_grafana_prometheus]: /posts/host_grafana_prometheus/
[node_exporter]: https://github.com/prometheus/node_exporter/releases/tag/v1.7.0
[go]: https://go.dev/doc/install
[readme]: https://github.com/xperimental/nextcloud-exporter?tab=readme-ov-file#token-authentication
[go]: https://go.dev/doc/install
[ncp]: https://github.com/theCalcaholic/ncp-monitoring-dashboard
[ncp_json]: https://github.com/theCalcaholic/ncp-monitoring-dashboard/blob/main/config/grafana/dashboards/ncp.json