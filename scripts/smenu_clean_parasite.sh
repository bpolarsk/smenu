#!/usr/bin/ksh
set -xv
cd $SBIN
find . -name sqlnet.log -exec ls -l {} \;
find . -name sqlnet.log -exec rm {} \;

find . -name afiedt.buf -exec ls -l {} \;
find . -name afiedt.buf -exec rm {} \;
