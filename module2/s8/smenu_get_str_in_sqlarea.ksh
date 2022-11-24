#!/bin/ksh
#set -x
#---------------------------------------------------------------------------------
# program: smenu_get_str_in_sqlarea.ksh
# Author : 
# Date   : 08-Febuary-2006
#---------------------------------------------------------------------------------
SBINS=$SBIN/scripts
FLEN=60
if [ -z "$1" ];then
   echo "I need a sub part of an sql"
fi
if [ "$1" = "-u" ];then
   AND_OWNER=" and parsing_schema_name = upper('$2') "
   shift 
   shift
fi


if [ "$1" = "-rac" ];then
   INST_ID='inst_id,'
   G=g
   shift
fi
if [ "$1" = "-len" ];then
   FLEN=$2
   shift
   shift
fi
STR=$@
STR="%$STR%"

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 32000 pages 66  head on
col parsing_schema_name head 'User' for a16
col PLAN_HASH_VALUE head 'Plan id' for 999999999999
col EXECUTIONS head 'Tot|execs' for 999999999
col gets head 'Tot|Buffer gets' for 9999999999 justify c
col disk_reads head 'Tot|Disk reads' for 9999999999 justify c
col child_number head 'Ch|ld' format 99
col cost form 999999 head 'Cost'
col sql_text for a${FLEN} head 'Sql Text'
col lat for a11 head 'Last Active time'
col ela for 99999999990,9 head 'Elapsed|time(ms)' justify c
col inst_id for 9999 head 'Inst'

select /*+ comment */ $INST_ID sql_id,child_number,PLAN_HASH_VALUE, optimizer_cost cost, EXECUTIONS, 
     buffer_gets gets, disk_reads ,parsing_schema_name, 
     decode(nvl(executions,0),0,0,round((elapsed_time/executions/1000) ) ) ela,
     to_char(last_active_time,'DD/HH24:MI:SS') lat , substr(sql_text,1,$FLEN) sql_text
from 
     ${G}v\$sql a
where 
        upper(sql_text) like upper('${STR}') $AND_OWNER
   and substr(sql_text,1,12) != 'EXPLAIN PLAN' 
   and substr(sql_text,1,21) != 'select /*+ comment */' 
/
exit
EOF

