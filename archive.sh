#! /bin/bash

sort --help | grep -i random > /dev/null

if [[ $? -eq 1 ]]; then
  LINKS=$(cat links.txt)
else
  LINKS=$(cat links.txt | sort -R)
  echo " -- Randomized Links."
fi

for u in $LINKS; do
  curl -sL --data-urlencode "url=$u" https://archive.is/submit/ > /dev/null
  out=$?

  if [[ $out -gt 0 ]]; then
    echo $u - $out
  fi
done
