#!/bin/sh
# set -xv
# author : found on asktom.com, adapted to Smenu by bpa
# B. Polarski
# 23 May 2005
WK_SBIN=$SBIN/module3/s1
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

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 170
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show SGA free memory (in mb)' nline
from sys.dual
/

set head on

COL tot_sga           FORMAT  999,999  justify c HEADING 'Total SGA'
COL free_per          FORMAT  999.99        HEADING 'Free |Perc '
COL FREE              FORMAT  999,999   justify c HEADING 'Free'

select  round(sum(bytes)/1024/1024,2) tot_sga,
round(sum(decode(name,'free memory',bytes,0))/1024/1024,2) free,
round((sum(decode(name,'free memory',bytes,0))/1024/1024)/(sum(bytes)/1024/1024)*100,2) free_per
from v\$sgastat
/
EOF
