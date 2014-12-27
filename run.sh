#!/bin/bash
cd $HOME/glamify
source ~/.rvm/scripts/rvm use 2.0
/data/project/glamify/.rvm/rubies/ruby-2.0.0-p598/bin/rake queue:process 

