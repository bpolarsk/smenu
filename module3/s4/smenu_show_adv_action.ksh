#!/bin/sh
# set -xv
# author :  B. Polarski
# 21 June 2005
WK_SBIN=$SBIN/module3/s6
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
FOUT=$SBIN/tmp/advction$$.txt
cd $WK_SBIN
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
sqlplus -s "$CONNECT_STRING" <<EOF

spool $FOUT
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 132
set termout on pause off
set embedded on
set verify off
set heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show advisor actions' nline
from sys.dual
/

break on task_name on command
set head on
COL task_name       FORMAT  A20 heading 'Task'
COL command         FORMAT  A19 heading 'Command'
COL tt              FORMAT  A80   HEADING ' Type'

select TASK_NAME, COMMAND, ATTR1 tt from dba_advisor_actions
union
select TASK_NAME, COMMAND, ATTR2 tt from dba_advisor_actions where attr2 is not null
union
select TASK_NAME, COMMAND, ATTR3 tt from dba_advisor_actions where attr3 is not null
union
select TASK_NAME, COMMAND, ATTR3 tt from dba_advisor_actions where attr4 is not null
/
EOF

echo "spool in $FOUT"
