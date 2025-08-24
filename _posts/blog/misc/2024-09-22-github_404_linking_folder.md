---
layout: post_markdown
title: Fix a 404 error when a folder without index.html is linked on GitHub Pages
description: GitHub does not serve root URLs (ending with a "/") unless there is an "index.htm". Good to know!
tags:
- Home Lab
- Self-hosted
- This Blog
---
# Fix a 404 error when a folder without index.html is linked on GitHub Pages

This is a funny bug, but can be really confusing.

When I was testing the site locally with my own `jekyll` server, everything was
fine. I could inside the link to a folder within the site, and the browser would
display a page like an FTP server.

![WEBrick](/assets/images/misc/404/webrick.png)

Then, I pushed the codes to GitHub, only to realize that the page did not work
as I was expecting.

![404](/assets/images/misc/404/404.png)

The reason is already shown on the page,

```text
For root URLs (like http://example.com/) you must provide an index.html file.
```

We need to add an `index.html` to the folder, so I just created a most basic
one in `assets/codes/hyperparameter_optimization`.

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File List</title>
</head>

<body>

    <h1>Files in hyperparameter_optimization</h1>

    <ul>
        <li><a href="ax_opt_ray.py">ax_opt_ray.py</a></l>
        <li><a href="parameters.json">parameters.json</a></l>
        <li><a href="process_QM7_data.py">process_QM7_data.py</a></l>
        <li><a href="QM7_ax_example.py">QM7_ax_example.py</a></l>
    </ul>
</body>

</html>
```

It looked like this,

![A basic index.html](/assets/images/misc/404/basic.png)

but I was not happy with it apparently, so I decided to theme it a little bit.

I basically took the homepage rendered by the GitHub action, and copied and
pasted all the headers and footers into this basic html, which resulted in the
page you can see
[here](https://tautomer.github.io/assets/codes/hyperparameter_optimization/). 