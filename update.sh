#! /bin/bash

RUBY=~/.rvm/environments/ruby-2.3.0

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
git ci links.txt -m 'update links'
rake build_cache
git ci cache.* -m 'update cache'
rake clean
git ci cache.* -m 'clean cache'
git st
git push
