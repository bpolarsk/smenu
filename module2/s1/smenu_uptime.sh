#!/bin/ksh
# set -xv
# B. Polarski
# 23 May 2005
WK_SBIN=$SBIN/module2/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID ' 
column nline newline
set pagesize 66
set linesize 170
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'DB uptime ' nline
from sys.dual
/

set head on

COL startup_time        FORMAT A34      HEADING '   Startup time'
COL status              FORMAT A10      heading 'Status'

SELECT '   ' || to_char(startup_time,'HH24:MI:SS YYYY-MON-DD') startup_time, status
from v\$instance
/

EOF
