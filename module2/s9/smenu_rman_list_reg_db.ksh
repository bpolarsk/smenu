#!/usr/bin/ksh
# set -xv

# Author: Jim Czuprynski
# Adapted to Smenu by B. Polarski
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
RMAN_USER=$(echo "`sqlplus -s \"$CONNECT_STRING\" <<EOF
set head off  pagesize 0  feed off
select owner from all_views where view_name = 'RC_DATABASE' ;
EOF`" | awk '{ print $1}')
sqlplus -s "$CONNECT_STRING" <<EOF
clear screen
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'list registered database' nline
from sys.dual
/
prompt  -- RMAN OWNER : $RMAN_USER
prompt
set head on

SELECT NAME , DBID , DB_KEY , DBINC_KEY ,
 RESETLOGS_CHANGE#, RESETLOGS_TIME  
  FROM $RMAN_USER.RC_DATABASE
/
EOF
