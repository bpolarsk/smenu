#!/bin/sh
# set -xv
# program : smenu_dump_control_file.ksh
# date    : 21 November 2005

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# --------------------------------------------------------------------------
S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 128
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Dump control file' nline
from sys.dual
/

alter session set events 'immediate trace name CONTROLF level 10';
oradebug setmypid ;
oradebug tracefile_name ;


EOF


