#!/usr/bin/ksh
# set -xv

# Author: Jim Czuprynski
# Adapted to Smenu by B. Polarski

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
       'Username          -  '||USER  nline,
       'Display Flash back set up'
from sys.dual
/

set head on

Prompt -- Flashback Options Currently Enabled:

prompt

COL name                FORMAT A32      HEADING 'Parameter'
COL value               FORMAT A32      HEADING 'Setting'

SELECT  name ,value
  FROM v\$parameter 
 WHERE NAME LIKE '%flash%' OR NAME LIKE '%recovery%'
 ORDER BY NAME;

-- What's the status of the Flash Recovery Area?

prompt
PROMPT -- Flash Recovery Area Status:


COL name                FORMAT A32      HEADING 'File Name'
COL spc_lmt_mb          FORMAT 999999.99  HEADING 'Space|Limit|(MB)'
COL spc_usd_mb          FORMAT 999999.99  HEADING 'Space|Used|(MB)'
COL spc_rcl_mb          FORMAT 999999.99  HEADING 'Reclm|Space|(MB)'
COL number_of_files     FORMAT 99999    HEADING 'Files'

SELECT 
     name
    ,space_limit /(1024*1024) spc_lmt_mb
    ,space_used /(1024*1024) spc_usd_mb
    ,space_reclaimable /(1024*1024) spc_rcl_mb
    ,number_of_files
  FROM v\$recovery_file_dest;
  

-- Is Flashback Database currently activated for this database?

prompt
prompt Issue 'alter database flash back' if  flashback is not set
prompt

COL name                FORMAT A12      HEADING 'Database'
COL current_scn         FORMAT 99999999999999  HEADING 'Current SCN #'
COL flashback_on        FORMAT A15       HEADING 'Flash Back On?' justify c

SELECT
      name
     ,current_scn
     ,flashback_on
  FROM v\$database;

EOF
