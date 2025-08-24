---
layout: post_markdown
title: (Physically) install my OctoPrint server
description: A quick and dirty way to mount the OctoPrint printer under the desk.
tags:
- Home Lab
- 3D Printing
- OctoPrint
- DIY
---
# (Physically) install my OctoPrint server

At the time when I got my Voxelab Aquila X2 printer, I kept it in the corner of
a desk against the walls. After using the printer for a few month, I feel it it
necessary to hook it up with an OctoPrint server for easier and more advanced
controls. I happen to have a spare [ASRock N3050M Motherboard][N3050] featuring
an Intel Celeron N3050 CPU, which is perfect for this use case (low power and
relatively low demanding). Even better the desk where my printer is sitting, has
a bar underneath the surface, providing an excellent location to mount the
motherboard.

![The bar](/assets/images/3d_printing/N3050/ODUS-BT-SXDF-B-0.jpg)

I did not take enough pictures when doing this project, so you can probably tell
the writing is a little bit messy (not in chronological order). Please bear with
me.

## Some quick measurement

I found a piece of scrape plywood, whose size and thickness were perfect.

![The "case"?](/assets/images/3d_printing/N3050/IMG_20220319_113417.jpg)

The thickness is perfect that you can use all screws in a normal case, but it is
thin enough that it will not be too heavy.

I need to design and print two brackets to mount the "case" to the horizontal
bar, so its width is critical.

![Bar thickness](/assets/images/3d_printing/N3050/IMG_20220319_113337.jpg)

## Print the brackets

Actually 3 different kind of brackets are needed.

1. A set to mount the plywood to the desk.
2. A set to mount an old SATA SSD to the back of the plywood.
3. A PCI-E bracket to hold the wireless adapter to the plywood.

### Mounting bracket for the whole thing

(I should still have the model, but I am too lazy to take a screenshot.)

Anyway, the small holes are used to screw the bracket to the plywood.

![Bracket](/assets/images/3d_printing/N3050/IMG_20220319_133317.jpg)

The big hole perpendicular to the bracket is for the DC female port of the
[Pico PSU (example link, not an ad)][Pico PSU].

![DC port](/assets/images/3d_printing/N3050/IMG_20220319_133832.jpg)

The other bracket has a slot to hold the [power button like this][power button].

![Power button holder](/assets/images/3d_printing/N3050/IMG_20220319_161227.jpg)

Please ignore the wrapped corner. Not a big deal for a functional print. :)

### Mount brackets for the SSD

There are already existing models on thingiverse.com to mount 2.5'' disks to
whatever place. I just took one of these models and slightly modified it for my
needs.

![Disk brackets](/assets/images/3d_printing/N3050/IMG_20220319_112202.jpg)

Just lay the disk on the plywood and drill for 4 holes.

![Screw the disk in](/assets/images/3d_printing/N3050/IMG_20220319_160844.jpg)

### PCI-E bracket for the wireless card

The original stainless steel is too heavy and thin, so that it will be very
difficult to hold it on the plywood without a proper case. More importantly, the
motherboard will be mounted vertically under the desk, so the wireless card
might fall anytime -- I need something different.

![Printed PCI-E](/assets/images/3d_printing/N3050/wx_camera_1647630753143.jpg)

## Assemble everything

For a Micro-ATX motherboard, there are 6 mounting screws. 2 holes for each
bracket to mount the plywood to the disk. 4 holes for the SSD. Additionally, a
slot for the wireless adapter.

![All holes drilled](/assets/images/3d_printing/N3050/IMG_20220319_160558.jpg)

You can actually use the standard mounting screw for the motherboard.

![Motherboard screws](/assets/images/3d_printing/N3050/IMG_20220319_160958.jpg)

The only problem is that... these screws are not designed for woods, so crest of
the thread is not large enough. I just tossed some wasted PLA there and forced
the screw in.

![Recycling!](/assets/images/3d_printing/N3050/IMG_20220319_161013.jpg)

With the printed PCI-E bracket, the wireless adapter can stand there alone
without anything. I will have stable Internet!

![Wireless](/assets/images/3d_printing/N3050/IMG_20220319_111930.jpg)

This is how it looks like when everything is in-place.

![Fully assembly](/assets/images/3d_printing/N3050/IMG_20220319_162814.jpg)

Then I can go ahead and mount it under desk. Done!

![Mount it under the desk](/assets/images/3d_printing/N3050/IMG_20220319_162905.jpg)

You might have noticed the purple wood attached to the plywood. It is the safety
measure. Even if the brackets fail, the plywood will not drop to the ground.

[N3050]: https://www.asrock.com/mb/Intel/N3050M/
[Pico PSU]: https://www.amazon.com/Mini-Box-picoPSU-160-XT-Power-Mini-ITX-Supply/dp/B005TWE6B8
[power button]: https://www.amazon.com/Warmstor-3-Pack-Desktop-Button-Computer/dp/B072FMVZJZ 