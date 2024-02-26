#!/bin/bash

dir=${PWD##*/}
yaml=$dir.yml
echo -e "picture_path: $dir\npictures:" > $yaml

cd originals
for i in *.jpg
do
    basename=${i%.*}
    echo "- filename: $basename" >> ../$yaml
    sizes=$(identify -ping -format '%wx%h' $i)
    # copy original to ../original-wxh.jpg
    cp $i ../$basename-$sizes.jpg  
    echo "  original: $basename-$sizes.jpg" >> ../$yaml
    # resize to half
    convert $i -resize 50% tmp.jpg
    sizes=$(identify -ping -format '%wx%h' tmp.jpg)
    mv tmp.jpg ../$basename-$sizes.jpg  
    echo -e "  sizes:\n  - $basename-$sizes.jpg" >> ../$yaml
    # create a thumbnail
    convert $i -resize 1000x1000 tmp.jpg
    mv tmp.jpg ../$basename-thumbnail.jpg  
    echo "  thumbnail: $basename-thumbnail.jpg" >> ../$yaml
done