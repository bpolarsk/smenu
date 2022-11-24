#!/usr/bin/ksh
# set -xv

# Author: Jim Czuprynski
# Adapted to Smenu by B. Polarski
# 18-April-2005

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
       'Display Database Flashback Limits'
from sys.dual
/

set head on  
COL oldest_flashback_scn     FORMAT 999999999 HEADING 'Oldest|Flashback|SCN #'
COL oldest_flashback_time    FORMAT A20       HEADING 'Oldest|Flashback|Time'
COL retention_target         FORMAT 999999999 HEADING 'Oldest|Flashback|SCN #'
COL flashback_size           FORMAT 999999999 HEADING 'Oldest|Flashback|Size'
COL estimated_flashback_size FORMAT 999999999 HEADING 'Estimated|Flashback|Size'

SELECT
      oldest_flashback_scn
     ,oldest_flashback_time
     ,retention_target
     ,flashback_size
     ,estimated_flashback_size
  FROM v\$flashback_database_log;

Prompt
prompt Available flash back logs :
prompt


TTITLE 'Current Flashback Logs Available'
COL log#                FORMAT 9999     HEADING 'FLB|Log#'
COL bytes               FORMAT 99999999 HEADING 'Flshbck|Log Size'
COL first_change#       FORMAT 99999999 HEADING 'Flshbck|SCN #'
COL first_time          FORMAT A24      HEADING 'Flashback Start Time'

SELECT
    LOG#
    ,bytes
    ,first_change#
    ,to_char(first_time,'YYYY-MM-DD HH24:MI:ss') first_time
  FROM v\$flashback_database_logfile;

EOF
