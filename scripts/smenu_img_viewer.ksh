#!/usr/bin/bash
if [ -n "$1" ];then
   TARGET=$1
   ps -f | grep -q firefox
   if [ $? -eq 0 ];then
      exec firefox -new-tab file:///$TARGET &
   else
      exec firefox file:///$TARGET &
   fi
else
  echo "Firefox not found in path"
fi
