#!/bin/sh
#---------------------------------------------------------------------------------
# view v$sysstat values
#---------------------------------------------------------------------------------
if [ "x-$1" = "x-" ];then
     echo "I need an session SID "
     exit
fi
SID=$1
if [ "x-$2" = "x--n" ];then
   ORDER="order by name"
elif [ "x-$2" = "x--s" ];then
   ORDER="order by statistic#"
elif [ "x-$2" = "x--c" ];then
   if [ ! "x-$2" = "x-" ];then
      ORDER="and class = $3"
   else
      ORDER="order by class"
   fi
else
   ORDER=
fi
SBINS=$SBIN/scripts

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

TMP=$SBIN/tmp
cd $TMP
FOUT=$SBIN/tmp/v_sesstat_${ORACLE_SID}.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report values from v\$sysstat' nline
from sys.dual
/

set linesize 110
set heading on

column name        format a60 heading "Name"
column STATISTIC#  heading "Stat id"
column class       heading "Class"
column value       heading "Value"

prompt
prompt Type 'vste <SID> -n' to sort by name
prompt Type 'vste <SID> -s' to sort by stat id
prompt Type 'vste <SID> -c' to sort by class or 'vst -c <class id>' to show only one class
prompt

select b.sid, b.STATISTIC#,a.NAME,a.CLASS,b.VALUE${MEGS}
from
  v\$sysstat a  ,  v\$sesstat b
  where b.sid = $SID and
        a.STATISTIC# = b.STATISTIC# and b.value > 0
  $ORDER
/
spool off
EOF

if $SBINS/yesno.sh "To view the log" DO Y
   then
    vi $FOUT
fi
