#! /bin/bash

sort --help | grep -i random > /dev/null

if [[ $? -eq 1 ]]; then
  LINKS=$(cat links.txt)
else
  LINKS=$(cat links.txt | sort -R | head -n 30)
  echo " -- Randomized Links."
fi

for u in $LINKS; do
  curl -sv --data-urlencode "url=$u" https://archive.is/submit/ 2>&1 >/dev/null | grep '< HTTP/1.1' | grep -v 302
done
