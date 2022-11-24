#!/bin/sh
# set -xv
# author  : Amar Kumar Padhi
# program : smenu_list_obj_no_stat.ksh
# date    : 01 October 2005
# Apapted to Smenu by B. Polarski

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
if [  -n "$1" ];then
   OWNER=$1
else
    echo "I need and owner name"
    exit
fi
FOUT=$SBIN/tmp/lst_obj_with_no_stats_${OWNER}_${ORACLE_SID}.log
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------

#sqlplus -s "$CONNECT_STRING" > $FOUT  <<EOF
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 100
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show objects Without statistics' nline
from sys.dual
/

set head ON PAGESIZE 0
set linesize 124
set serveroutput 
declare
      l_owner       varchar2(30) := '$OWNER';
      l_emptylst    dbms_stats.objecttab;
    begin
      dbms_stats.gather_schema_stats(ownname => l_owner, options => 'LIST EMPTY', objlist => l_emptylst);
      for i in nvl(l_emptylst.first, 0) .. nvl(l_emptylst.last, 0) loop
        dbms_output.put_line(l_emptylst(i).objtype || '/' || l_emptylst(i).objname);
      end loop;
   end;
/
EOF


echo '********************************************************************'
echo "log file: $FOUT"
echo '********************************************************************'
echo

if $SBINS/yesno.sh "To see the log" DO Y
then
   vi $FOUT
fi
