#!/bin/sh
#---------------------------------------------------------------------------------
# view v$sysstat values
#---------------------------------------------------------------------------------
MEGS=
if [ "x-$1" = "x--n" ];then
   ORDER="order by name"
elif [ "x-$1" = "x--s" ];then
   ORDER="order by statistic#"
elif [ "x-$1" = "x--c" ];then
   if [ ! "x-$2" = "x-" ];then
      ORDER="where class = $2"
   else
      ORDER="order by class"
   fi
elif [ "x-$1" = "x--m" ];then
   MEGS="/1048576"
else
   ORDER=
fi
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

TMP=$SBIN/tmp
cd $TMP
FOUT=$SBIN/tmp/v_sysstat_${ORACLE_SID}.txt

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

set linesize 120
set pagesize 120
set heading on

column name        format a60 heading "Name"
column STATISTIC#  heading "Stat id"
column class       heading "Class"
column value       heading "Value"

prompt
prompt Type 'vst -n' to sort by name
prompt Type 'vst -s' to sort by stat id
prompt Type 'vst -c' to sort by class or 'vst -c <class id>' to show only one class
prompt Type 'vst -m' to have value in megs
prompt

select STATISTIC#,NAME,CLASS,VALUE${MEGS}
from
  v\$sysstat   
  $ORDER
/
spool off
EOF

if $SBINS/yesno.sh "To view the log" DO Y
   then
    vi $FOUT
fi
