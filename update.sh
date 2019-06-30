#! /bin/bash

RUBY=~/.rvm/environments/ruby-2.6.3

if [[ ! -f $RUBY ]] ; then
  echo "File $RUBY is not there, aborting."
  exit
fi

source $RUBY

git pull
bundle update
git ci Gemfile* -m 'bundle update'

echo "" > links.txt
rake update_links
rm links.json
for l in $(cat links.txt); do echo "{\"url\": \"$l\"}" | jq --compact-output . >> links.json; done
git ci links.* -m 'update links'

rake build_cache
git ci cache.* -m 'update cache'
rake clean
git ci cache.* -m 'clean cache'
git st
git push

cat cache.json | jq --compact-output '.[]' > output.json
bq load --time_partitioning_expiration=-1 --autodetect --source_format=NEWLINE_DELIMITED_JSON inspiration.cache output.json
rm output.json

bq load --time_partitioning_expiration=-1 --autodetect --source_format=NEWLINE_DELIMITED_JSON inspiration.links links.json
