#!/usr/bin/ksh
#set -xv

if [ "x-$1" = "x-" ];then
   echo "I need a datafile Number ID"
   exit 
fi
ID=$1

SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<EOF

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 2
column nline newline
set pause off pagesize 66 linesize 80 heading off embedded on termout on verify off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List extents occupancy for Datafile ID = $ID  ' nline
from sys.dual
/

col SEGMENT_NAME format a30
col owner format a15
set head on
break on owner
select OWNER,SEGMENT_NAME, BLOCK_ID, (BLOCK_ID + BLOCKS -1) END_EX, blocks
       from dba_extents where file_id = $ID 
order by BLOCK_ID
/

EOF
