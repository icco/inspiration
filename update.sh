#! /bin/bash

bundle update
git ci Gemfile* -m 'bundle update'
echo "" > links.txt
rake get_old
git ci links.txt -m 'update links'
git push
