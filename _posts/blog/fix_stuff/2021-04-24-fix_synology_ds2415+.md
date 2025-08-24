---
layout: post_markdown
title: Fixing Synology DS2415+ 
description: There is a hardware bug in certain Intel Atom CPUs. These CPUs will degrade over time and eventually the computer will not boot up due to the clock issue of the CPU. Funnily, fixing the problem only need one resistor to be soldered on the motherboard. The only thing is that the CPU will die again and by that time, there is no way to fix it.
tags:
- Home Lab
- Synology
- Self-hosted
- Intel
- DIY
- Fix-it
---

# Fixing Synology DS2415+

## The problem

Long story short. In January, the manager of computers in our department told me
the Synology NAS DS2415+ for our group was dead for unknown amount of time... By
checking my backup logs, I found the device has been died in the end of
November...

Without too much thinking, we both accepted the fact that the NAS has died, so
we should just leave it there for the time being. Until this week... one of our
postdocs asked me how to back her data up, so I thought why not check what
exactly happened to the NAS, since its situation would not get any worse anyway.

So I just googled "ds2415+ motherboard repair". To my surprise, there are many
posts where the devices were in the same or very similar situations. To name a
few,

* [PSA for those having issues with the Atom C2000 variants of Synology
  Diskstation (DS1515+, DS1815+, DS415+,
  etc.)](https://www.reddit.com/r/synology/comments/ix3b4a/psa_for_those_having_issues_with_the_atom_c2000/)
* [Intel c2000 failures](https://community.synology.com/enu/forum/1/post/120548)
* [C2538 Clock Fix Confirmed -
  DS2415+](https://www.reddit.com/r/synology/comments/609u1l/c2538_clock_fix_confirmed_ds2415/)
* [Replace motherboard of broken
  DS2415+](https://www.reddit.com/r/synology/comments/cebu0r/replace_motherboard_of_broken_ds2415/)

All these posts point to the same problem: the CPU used in these NAS, Intel Atom
C2358 failed, due to a flaw in the clock signal component. The component
degrades over time. Eventually (usually after around 18-month use), the
component starts to fail and then the device will not boot. Our NAS was bought
in 2016 and made all the way to the end of 2020, which is kind of impressive.

## The way to fix it

The fix is simple, soldering a 100 Ω resistor on two pins on the motherboard.

![A resistor soldered to the
motherboard](/assets/images/fix_stuff/fixing_synology/fix_reddit.jpg)

The image above was posted by [u/adprom](https://www.reddit.com/user/adprom/) in
[this post](https://www.reddit.com/r/synology/comments/609u1l/c2538_clock_fix_confirmed_ds2415/).

## Apply the fix to our Synology

Time to tear own machine down! Unfortunately, I did not take photos when taking
the NAS apart, but the process was straightforward. To summarize, 

1. Remove the top panel,
2. Remove all cabled connected to the motherboard,
3. Remove all four screws holding the right panel,
4. Remove the motherboard from the right panel.

![The motherboard of DS2415+](/assets/images/fix_stuff/fixing_synology/mobo.jpg)

The motherboard of DS2415+. Green box is socket for the "internal USB drive" for
the stock DSM. We will solder the resistor on the pin 1 and 6 in the red box.
The pin the bottom right corner is pin 1.

To test if the fix could really work on our NAS, I used two DuPont wires to
temporarily connect the resistor onto the motherboard.

![Test if it will work...](/assets/images/fix_stuff/fixing_synology/dupont.jpg)

So the resistor just loosely connected to the pins. As long as I do not touch
the motherboard, the contact seems to be stable. Then I plugged the RAM in and
only connected the 24-pin ATX connector, 4-pin EPS connector and the front LED
cable. And guess what? The device booted up, though the status LED was amber
because there was no bootable drive detected.

![Successful minimal boot](/assets/images/fix_stuff/fixing_synology/minboot.jpg)

All good! Let's connect everything back, including all the disks and the rear
fans **(If the rear fans are not connected, the NAS will flash an amber alert
LED and beep every 3 seconds.)** and test again!

![Successful boot](/assets/images/fix_stuff/fixing_synology/fixed.jpg)

With disk and everything connected, I got all green lights, which means the NAS
was already in a perfect functioning order. However, to be 100% sure, I decide
that I should see the web portal at least. Since our NAS has a static IP address
in the settings, I could not access the web UI directly. The trick is change the
IPv4 address of the network adapter to the same range as the static IP of the
NAS, set the mask t0 255.255.255.0, and leave everything else blank. Of course,
I saw the web portal.

Perfect! Time to solder the resistor on the back of the motherboard and this
time, it took my 6 to 7 times to finally get a kinda stable soldering.... This
was the first time for me to actually solder anything. Apart from my poor
skills, I did not have soldering flux which could also be the problem. To make
it even worse, I did not cut the legs at all, so there was a whole lot of metal
exposed right above the pins and contacts of the motherboard... Obviously, this
could be huge safety concern, so I decide to use an insulation tape to cover the
pins that could touch the lead of the resistor. (lol what a solution!)

![My not-so-useful solder](/assets/images/fix_stuff/fixing_synology/solder.jpg)

RIP, my poor soldering skills. In fact, the technician in our department redid
the soldering one day later... because my solder already failed the time when I
moved the box from my apartment back to our building...

Now the NAS fully revived! I saved some hundred bucks for my advisor.
