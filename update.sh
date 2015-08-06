#! /bin/bash
source ~/.rvm/environments/ruby-2.2.2

bundle update
git ci Gemfile* -m 'bundle update'
echo "" > links.txt
rake get_old
git ci links.txt -m 'update links'
rake build_cache
git ci cache.json -m 'update cache'
git st
git push
