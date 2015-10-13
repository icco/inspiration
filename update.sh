#! /bin/bash
source ~/.rvm/environments/ruby-2.2.3

git pull
bundle update
git ci Gemfile* -m 'bundle update'
echo "" > links.txt
rake get_old
git ci links.txt -m 'update links'
rake build_cache
git ci cache.* -m 'update cache'
git st
git push
