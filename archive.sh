#! /bin/bash

for u in $(cat links.txt); do
  echo $u
  curl -sL --data-urlencode "url=$u" https://archive.is/submit/ > /dev/null
  echo $?
done
