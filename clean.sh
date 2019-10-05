#! /bin/bash

RUBY=~/.rvm/environments/ruby-2.6.3

if [[ ! -f $RUBY ]] ; then
  echo "File $RUBY is not there, aborting."
  exit
fi

source $RUBY

git pull
bundle install 

rake clean
