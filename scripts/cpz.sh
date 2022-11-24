#!/bin/sh
trap ' rm /tmp/pipe$$ ' 0 1 2 3 4 5 6 7 8 9  13 15
#set -xv
# this utility copy any file in compress mode. use it instead of cp
# Given the frequency of its usage, not test is made on the exitence
# of the files, in order to gain some speed.

FIN=$1
FOUT=$2.Z
PIPE=/tmp/pipe$$
if [ -f $PIPE ];then
   rm $PIPE
fi
if [  -x /etc/mknod ];then
    MKNOD=/etc/mknod
elif [ -x /usr/sbin/mknod ];then
    MKNOD=/usr/sbin/mknod
else
    MKNOD=`which mknod`
fi
$MKNOD $PIPE p
cat $PIPE | compress > $FOUT &
cp $FIN $PIPE
