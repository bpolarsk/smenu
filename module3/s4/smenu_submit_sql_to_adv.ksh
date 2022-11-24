#!/bin/sh
# set -xv
# author :  B. Polarski
# 21 June 2005
WK_SBIN=$SBIN/module3/s6
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SQL=$SBIN/tmp/submit_adv$$.sql
cd $WK_SBIN

TAG=smenu_submit$$
typeset -u schema
typeset -i secs
secs=45
echo ""
echo " The text file must only contain the sql statement, "
echo " no comments or setting after the SQL"
echo " The SQL statment must be terminated by  ';'"
echo ""
echo "input the full path of the sql file to submit ==> \c"
read sqlfile
if  [ ! -f "$sqlfile" ];then
    echo "error: file $sqlfile not found"
    read err
    exit 0
fi 
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
echo "input the schema which will execute the SQL [default $S_USER] ==> \c"
read ttf
echo "maximum number of seconds that SQL advisor will run [default $secs] ==> \c"
unset tts
typeset -i tts
read tts 
schema=${ttf:-$S_USER} 
seconds=${tts:-$secs}

if  [ "$S_USER" != "$schema" ];then
       echo "I will need the passwd of $schema ==> \c"
       read spass
       S_USER=$schema
       PASSWD=$spass
fi
TT=$(cat $sqlfile)
cat > $SQL <<EOF
 DECLARE
 task_name varchar2(30);
 sql_stmt clob ;
  
BEGIN
   sql_stmt := '$TT' ;

   task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK (
        sql_text => sql_stmt,
        bind_list => sql_binds (anydata.ConvertNumber(32)),
        user_name => '$schema',
        scope => 'COMPREHENSIVE',
        time_limit => $seconds,
        task_name => '$TAG',
        description => 'submited by smenu for tuning');

   dbms_output.put_line('Task ' || task_name || 'has been created' ); 
   dbms_sqltune.execute_tuning_task (task_name => '$TAG');
END ;
EOF

sqlplus -s "$CONNECT_STRING" <<EOF
@$SQL
/
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 132
set termout on pause off
set embedded on
set verify off
set heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Execution of task ' nline
from sys.dual

set serveroutput on size 100000
set long 1000
set longchunksize 1000
select dbms_sqltune.report_tuning_task('$TAG') from dual ;
exit
EOF
