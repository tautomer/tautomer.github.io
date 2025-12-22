---
layout: post_markdown
title: Back up NAS photos to Google Photos using Pixel XL without explicitly copying files
description: If you have a spare og Pixel or Pixel XL, you have free unlimited Google Photos backup at the original quality. Here is the catch. If you have a large amount of data, batch copying everything to the phone's internal storage, backing it up, and then deleting can be a problem to the longevity of the phone's storage. Instead of explicitly copying, this is a simple setup guide to back up photos from a NAS to Google Photos using a Pixel XL device.
tags:
- Home Lab
- Self-hosted
- Photography
- NAS
---
# Back up NAS photos to Google Photos using Pixel XL without explicitly copying files

I recently purchased a used Pixel XL to take advantage of the free unlimited
Google Photos backup at the original quality. However, I faced a challenge when
trying to back up a large collection of photos stored on my NAS. The simplest
solution is apparently to copy all photos to the phone's internal storage, let
Google Photos back them up, and then delete them from the phone. However, this
approach raises concerns about the longevity of the phone's storage due to the
large amount of data being written and deleted. (Though if you do the math,
backing up a total 5TB of data will only cause about 10% wear of the eMMC. Still
I would like to avoid unnecessary wear and tear.)

Warning: This method is slooooow if you have a large SMB share. Be patient.

This guide was inspired by [a comment on a blog][post].

## Prerequisites

1. A Pixel or Pixel XL device. You do not have to the original owner.
2. A NAS with SMB share enabled.
3. You are ok with rooting your Pixel device. This is the only way to mount
   network shares as internal storage, which is required for Google Photos to
   see and process the files.

## Steps

### 1. Root your Pixel device

Root your Pixel device using [Magisk][magisk]. If you have ever rooted an
Android device before, you must have heard of Magisk. (Hey, I still miss the
days that it was more of an obligation to root Android devices.) Just follow the
official [Magisk installation guide][magisk_installation]. Not gonna lie, after
a solid 6 years using non-rooted Android devices, I had to spend some time to
get familiar with the process again. Many things did not change, but lots of
stuff is not the same as before.

### 2. Install the rclone-mount module

After you have the device rooted, we need to install a Magisk module called
[rclone-mount][rclone_mount]. This module allows you to mount network shares
using `rclone`, which supports SMB protocol. There is a fork of the repo called
[rclone-mount-magisk][rclone_mount_fork], which appears to be the top result if
you google "magisk rclone mount". DO NOT use that. Its bundled `rclone` binary
is too old and does not support SMB mounts.

Now, here is the tricky part. The repo has been abandoned and archived for years
and there were no tags for newer releases. I suppose it (as a part of the
official Magisk module repo) was released through the module manager, but it was
gone due to legal concerns.

Luckily, the og pixel has been abandoned by Google as well, so the archived
codes still work fine. Here is how you can get a functional version of the
module.

1. Get the repo (master branch) through a method you like. Note that if you use
   the "Download ZIP" button on GitHub, you will get a ZIP file that contains
   one more level of directory `com.piyushgarg.rclone-master`, which will need
   to get rid of.

2. Anyway, we have the folder now. You can choose to remove the readme and
   changelog files if you want, but all the rest are essential for the module.

3. Modify the installation script `install.sh` file to create an additional
   symlink and use latest `rclone` binary. 

   1. Optionally replace the download links in the following block for `arm64`,
      as we will only use this for our Pixel.
      
      ```shell
        if [ "$ARCH" == "arm" ];then
          ui_print "+ downloading rclone-$ARCH to $MODPATH/rclone"
          curl "https://beta.rclone.org/test/testbuilds-latest/rclone-android-16-armv7a.gz" | gunzip -d - > "$MODPATH"/rclone
        elif [ "$ARCH" == "arm64" ];then
          ui_print "+ downloading rclone-$ARCH to $MODPATH/rclone"
          curl "https://beta.rclone.org/test/testbuilds-latest/rclone-android-21-armv8a.gz" | gunzip -d - > "$MODPATH"/rclone
        elif [ "$ARCH" == "x86" ];then
          curl "https://beta.rclone.org/test/testbuilds-latest/rclone-android-16-x86.gz" | gunzip -d - > "$MODPATH"/rclone
        elif [ "$ARCH" == "x64" ];then
          curl "https://beta.rclone.org/test/testbuilds-latest/rclone-android-21-x64.gz" | gunzip -d - > "$MODPATH"/rclone
        fi
     ```
     Replace `https://beta.rclone.org/test/testbuilds-latest` with
     `https://beta.rclone.org/v1.72.0/testbuilds` or `v1.71.0`. I have tested
     them myself. While the current latest build works, you will never know if
     it will break in the future.

    2. In the following block, we need to link `fusermount` to `fusermount3` as well.
        
       ```shell
       set_permissions() {
         # The following is the default rule, DO NOT remove
         set_perm_recursive $MODPATH 0 0 0755 0644
         set_perm $MODPATH/rclone 0 0 0755
         set_perm $MODPATH/fusermount 0 0 0755
         set_perm $MODPATH/fusermount-wrapper.sh 0 0 0755
         set_perm $MODPATH/service.sh 0 0 0755
         set_perm $MODPATH/rclonew 0 0 0755
         set_perm $MODPATH/syncd.sh 0 0 0755
         set_perm $MODPATH/inotifywait 0 0 0555

         ln -sf $MODPATH/rclone /sbin/rclone
         ln -sf $MODPATH/rclonew /sbin/rclonew
         ln -sf $MODPATH/fusermount /sbin/fusermount
        
         ...
       }
       ```

       Add the following line after the last `ln -sf` line.

       ```shell
         ln -sf $MODPATH/fusermount /sbin/fusermount3
       ```
    
      This should allow us to mount the SMB share without issues.

4. Modify `common/service.sh` to create the `fusermount3` symlink every time
   the module is started. Add the following line after the existing `ln -sf`
   lines in the middle of the file.

   ```shell
   ln -sf ${HOME}/fusermount /sbin/fusermount3
   ```

5. Zip the folder to a ZIP file. Make sure the contents of the repo is directly
   in the root of the ZIP file, so the top level is directly `install.sh`,
   `binary`, etc. 

6. Transfer the ZIP file to your Pixel device and install it through Magisk.

### 3. Configure and mount the SMB share

The file we need to create/modify is `/sdcard/.rclone/rclone.conf`. Here is my
config file. You can create the file on the computer through `rclone config` 

```ini
[DeepDarkFanta]
type = smb
host = deepdarkfantasy.lan
user = username
pass = password
```

The section `DeepDarkFanta` is the SMB share connection. `DeepDarkFanta` is the
name of the connection, so you can name it whatever you want. Replace
`deepdarkfantasy.lan` and `username` with your NAS's IP address or hostname and
username when running `rclone config`. `rclone` will also ask yor password and
store it in the config file encrypted.

With this, `rclone` will mount all the SMB shares of you NAS to
`/mnt/cloud/connection_name`. We do not want to mount everything as internal
storage, so the next step is crucial. For example, all my photos are stored in
the SMB share called `photo`. We will create an alias remote that only points to
that share.

```ini
[ddf_photos]
type = alias
remote = DeepDarkFanta:photo
```

Now, `rclone` will mount only the `photo` share to `/mnt/cloud/ddf_photos`,
alongside with everything under `/mnt/cloud/DeepDarkFanta`.

Till now, the mount will not be recognized as internal storage by Android. We
need to add a configuration file to mount it as internal storage and tune the
performance.

```ini
M_GID=1015
BINDSD=1
SDBINDPOINT=nas_photos
LOGLEVEL=NOTICE
DIRCACHETIME=1000h0m0s        
ATTRTIMEOUT=24h0m0s
BUFFERSIZE=36M
READCHUNKSIZE=256M
READAHEAD=4M
ADD_PARAMS="--read-only --transfers 8 --checkers 16"
```

- `M_GID=1015`: This is the GID of the `media_rw` group on Pixel XL. This group
  has permission to read and write media files. You can check the GID on your
  device through `ls -l /dev/block/platform/*/by-name/`. 

- `BINDSD=1` and `SDBINDPOINT=nas_photos`: This will mount the SMB share to
  `/sdcard/nas_photos`, which is required for Google Photos to see the files.

- The rest are performance tuning options. You can tweak them as you like, but
  increasing `DIRCACHETIME`, `BUFFERSIZE` and `READCHUNKSIZE` should help with
  indexing the huge folders. Also, I mounted the share as read-only to prevent
  any accidental deletion of files. This should be an upload-only setup.

**Note**: If the `param` file is created on Windows, the Carriage Return (CRLF)
will break the rclone script. Make sure to convert the line endings to Unix (LF)
format. If you have `termux` installed, you can use `sed` to globally remove the
CRLF characters.

```shell
sed -i 's/\r//g' /sdcard/.rclone/.your_remote_name.param
```

After all these, reboot your device. If everything goes well, you should see a
new folder `/sdcard/nas_photos` that contains all your NAS photos. Give Google
Photos sometime to realize this folder is an internal media folder and it will
start to index and back up the photos automatically. The indexing process can
take weeks (I have some dozens of thousands of photos and it is still going on
after a full week of continuous processing), so be patient.

I found that disabling battery optimization for Google Photos and keeping the
screen on while charging help speed up the process. However, the will get very
hot doing so, so I used my spare Thermalright Phantom Spirit as a passive
cooler, which is extremely effective. The cold plate does not even get warm.
 
![](/assets/images/homelab/pixel_cooling.jpg)

Sometimes when things are really stuck, you can try to kill the app and restart.

[post]: https://github.com/4ft35t/4ft35t.github.io/issues/3#issuecomment-1589689584
[magisk]: https://github.com/topjohnwu/Magisk
[magisk_installation]: https://topjohnwu.github.io/Magisk/install.html
[rclone_mount]: https://github.com/Magisk-Modules-Repo/com.piyushgarg.rclone
[rclone_mount_fork]: https://github.com/AvinashReddy3108/rclone-mount-magisk