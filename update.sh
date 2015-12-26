#! /bin/bash
source ~/.rvm/environments/ruby-2.3.0

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
