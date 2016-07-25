#! /bin/bash

for u in $(cat links.txt); do
  echo $u
  curl -s --data-urlencode "run=1&url=$u" https://archive.is/submit/ | grep -i archive.is | awk -F\" '{ print $2 }'
done
