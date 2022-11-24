#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=$SBIN/module3/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Database usage per user in DB ' nline
from sys.dual
/
set heading on
set linesize 190
col Owner head "User" justify l
col Total format 999,990 head "Total space|By user(mb)" justify c
col totdb format 999,990 head "Total space|in DB(mb)" justify c
col tbsperc justify right format A10 head "Percent in|Database" 
break on totdb
select owner, sum(bytes/1024/1024)   Total,
       totdb, '   ' || to_char(trunc((sum(bytes/1024/1024)*100)/totdb))   || '%' tbsperc
    from dba_extents a , 
         ( select trunc(sum(bytes/1024/1024)) totdb from dba_data_files ) b
    where owner not like 'SYS%' 
   group by owner, totdb  order by owner
/ 
exit

EOF
