---
layout: post_markdown
title: Copy location metadata with exiftool
description: A shell function to copy the GPS location from one media file to others
tags:
- Shell
- CLI
- Photography
---
# Copy location metadata with exiftool

One downside of using a digital camera is that you have to connect it to the
cell phone through Bluetooth to obtain the GPS information. My Panasonic S5II
connects to my phone through the LUMIX Sync app. Sometimes, the camera will not
get the GPS data right after the app connects the camera. Additionally, if you
put the LUMIX Sync app in the background, it would be killed by the system after
a few minutes, photos taken afterward will not have the GPS data. This will make
it very difficult to manage the photo libraries. I wrote this snippet so that I
can easily copy the location data from one photo to others.

## The code

Here I define a shell function called `copy-exif-location`.

```shell
# copy location
copy-exif-location() {
    local source="$1"
    shift
    local targets=("$@")
    for target in "${targets[@]}"
    do
        exiftool -overwrite_original -tagsFromFile "$source" \
        "-GPSLatitude>GPSLatitude" \
        "-GPSLongitude>GPSLongitude" \
        "-GPSLatitudeRef>GPSLatitudeRef" \
        "-GPSLongitudeRef>GPSLongitudeRef" \
        "-GPSAltitude>GPSAltitude" \
        "$target"
    done
}
```

After this function is added to the rc file, the copy location operation can be
done via

```shell
copy-exif-location source_file target_file
```

or

```shell
copy-exif-location source_file target_file_pattern*
```

or

```shell
copy-exif-location source_file target_file1 target_file2
```

One interesting thing to note is that the lines

```shell
        "-GPSLatitudeRef>GPSLatitudeRef" \
        "-GPSLongitudeRef>GPSLongitudeRef" \
```

are necessary. Otherwise, the programs parsing the metadata will throw you to
the Eastern Hemisphere and Northern Hemisphere, as the default (positive value)
for latitude is north and the default for longitude is east. Without these
references copied, a US coordinate will be parsed as a coordinate in China.