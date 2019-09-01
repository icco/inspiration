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

rake update_links
git push
