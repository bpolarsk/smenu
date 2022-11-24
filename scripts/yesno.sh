#!/bin/ksh

NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi


if [  -z "$1" ];then
    echo $NN "Are you sure (y/n) ?$NC"
else
    if [ -n "$2"  ];then
       if [  "$2" = "DO" ];then
          if [  "x-$3" = "x-Y" -o "x-$3" = "x-y" -o "x-$3" = "x-N" -o "x-$3" = "x-n" ];then
                echo ${NN} "     DO you want $1 (y/n)? [$3] $NC"
	  else
                echo ${NN} "     DO you want $1 (y/n) ? $NC"
	  fi
       fi
    else
       echo $NN "    Are you sure you want $1 (y/n) ? $NC"
    fi
fi
read resp
if [ "x-$resp" = "x-y" -o "x-$resp" = "x-Y" -o "x-$resp" =  "x-yes" -o "x-$resp" = "x-Yes" ];then
   exit 0
else
  if [ "x-$resp" = "x-" ];then
    if [ "x-$3" = "x-Y" -o "x-$3" = "x-y" ];then
       exit 0
    else
       exit 1
    fi
  else
    exit 1
  fi
fi
