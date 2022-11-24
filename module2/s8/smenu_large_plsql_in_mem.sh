#!/bin/sh
#set -xv
SBINS=$SBIN/scripts
#------------------------
if [ "x-$1" = "x-" ];then
   minvalue=10000
else
   minvalue=$1
fi
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

echo " Progran in progress ...."
sqlplus -s "$CONNECT_STRING" <<EOF

clear screen

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 100
set termout on
set heading off pause off
set embedded off
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List of Large PL/SQL Objects in memory' nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 190 pagesize 66 
col owner    form a15 head 'Owner'
col name     form a30 head 'Name'
col type     form a14 head 'Type'
col sharable_mem     form 999999 head 'Size in |Mem' justify c
col executions     form 999999 head 'Exec' justify c
col locks     form 99 head 'Lck' justify c
col pins     form 99 head 'Pins' justify c
col kept     form a4 head 'Kept|Mem'
col loads     form 999 head 'Nbr|Loads'

select owner,name,type,sharable_mem , loads , executions, locks,pins,kept
  from sys.v_\$db_object_cache
  where sharable_mem > '$minvalue'
   and (type = 'PACKAGE' or type = 'PACKAGE BODY' or type = 'FUNCTION'
        or type = 'PROCEDURE')
   and kept = 'NO' order by 6 desc

/ 
exit

EOF
