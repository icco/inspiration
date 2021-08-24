#! /bin/bash

RUBY=~/.rvm/environments/ruby-3.0.0

if [[ ! -f $RUBY ]] ; then
  echo "File $RUBY is not there, aborting."
  exit
fi

source $RUBY

git pull
bundle update
git ci Gemfile* -m 'bundle update'
git push

rake update
