#!/usr/bin/ksh 
#set -x
function help
{
  cat <<EOF

        sqt [ADDRESS] -s <sid> -a 

          -a : add hash_value  field to the output
          -s : limit selection to <sid>

EOF
}
SILENCE=N
OWNER=
ROWS=
LEN=60
ORDER=" order by 1 desc"
F_SID='sid,'
while [ -n "$1" ]  
do
  case $1 in
   -h ) help 
        exit;;
   -a ) F_ADDRESS=" q.hash_value,"  
        LEN=52
        DO_OTHERS=" select sid from v\$session where sql_hash_value = '&hash_value' or prev_sql_addr = '&hash_value' ;" ;;
   -s ) unset F_SID
        A_SID=" and s.sid = '$2'" 
        shift
        SILENCE=Y;;
     * ) fhash_value="'$1'"
         unset LEN
         unset F_ADDRESS
         DO_OTHERS=" select sid from v\$session where sql_hash_value = '&hash_value' or prev_sql_addr = '&hash_value' ;" ;;
  esac
  shift
done
#set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
FOUT=$SBIN/tmp/system_event_${ORACLE_SID}_`date +%m%d%H`.txt

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} 
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi

echo " Progran in progress ...."

if [ -n "$hash_value" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 80
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   '    Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set termout on
set embedded off
set verify off
set heading off pause off
spool $FOUT
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Locating CPU-Heavy SQL with Sid and Sql Text' nline
from sys.dual
/   
set head on pause off feed off embedded on
set linesize 124

prompt
prompt
column buffer_gets format 999999990 head "Buffer Gets" justify c
column executions format 9999990 head "Executions" justify c
column exec format 9999990 head "Gets/Exec" justify c
column sql_text format a60 head "Sql"
column hash_value format 9999999999 head "Hash_value"
column disk_reads format 99999990 head "Disk|Reads" justify c
column rows_processed format 9999999990 head "Rows|Processed" justify c
column sid format 9999 head "Sid" justify c
col hash_value new value hash_value
prompt
prompt .      sqt -s <sid> to limite to one user
prompt .          -a to add the sql hash_value 

SELECT   buffer_gets, executions, buffer_gets/executions exec, 
         disk_reads,rows_processed,sql_text    
FROM v\$sqlarea 
WHERE  hash_value = $hash_value
     and executions > 0  
     order by 1
/
select sid from v\$session where sql_hash_value = $hash_value or prev_sql_addr = $hash_value
/

spool off
prompt
EOF



else
# generql Sqt
sqlplus -s "$CONNECT_STRING" <<EOF

set linesize 80
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   '    Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set termout on
set embedded off
set verify off
set heading off pause off
spool $FOUT
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Locating CPU-Heavy SQL with Sid and Sql Text' nline
from sys.dual
/   
set head on pause off feed off embedded on
set linesize 124

prompt
prompt
column buffer_gets format 999999990 head "Buffer Gets" justify c
column executions format 9999990 head "Executions" justify c
column exec format 9999990 head "Gets/Exec" justify c
column sql_text format a$LEN head "Sql"
column hash_value format 9999999999 head "Address"
column disk_reads format 99999990 head "Disk|Reads" justify c
column rows_processed format 9999999990 head "Rows|Processed" justify c
column sid format 9999 head "Sid" justify c
col hash_value new value hash_value
prompt
prompt .      sqt -s <sid> to limite to one user
prompt .          -a to add the sql hash_value 
SELECT   $F_SID buffer_gets, executions, buffer_gets/executions exec, 
         disk_reads,rows_processed,$F_ADDRESS sql_text    
FROM 
     v\$sqlarea q, v\$session s 
WHERE 
     s.sql_hash_value = q.hash_value 
     and executions > 0  $A_SID 
     order by 1
/
$DO_OTHERS
spool off
prompt
EOF

fi

if [ $SILENCE = N ];then
    echo Result in $FOUT
fi
