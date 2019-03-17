#! /bin/bash

sort --help | grep -i random > /dev/null

LINKS=$(cat links.txt | sort -R | head -n 30)
echo " -- Randomized Links."

for u in $LINKS; do
  curl -s -I -H "Accept: application/json" "https://web.archive.org/save/${u}" | grep '^x-cache-key:' | sed "s,https,&://,; s,\(${u}\).*$,\1,"
  curl -sv --data-urlencode "url=$u" https://archive.is/submit/ 2>&1 >/dev/null | grep '< HTTP/1.1' | grep -v 302
done
