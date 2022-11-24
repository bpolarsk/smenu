#!/bin/sh
#set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

TMP=$SBIN/tmp
cd $TMP
# ------------------------------------------------------------------------------
help() {

     cat <<EOF

         shed  -h                          : this help
         shed  -l                          : List scheduled jobs
         shed  -log -u <schema>  -rn <nn>  : Show last logs
         shed  -r  <job name>  [-curr]     : Run a job now
         shed  -e  <job name>              : Enable a job
         shed  -d  <job name>              : Disable a  job
         shed  -drop  <job name>           : drop job
         shed  -lss                        : List scheduler schedule
         shed  -o                          : List scheduler overview
         shed  -rj                         : List Running jobs
         shed  -a                          : List program arguments



         -rn  <ROWNUM>   :  show only first <nn>  rows
         -u   <OWNER>    :  Restrict to Schema 
         -j   <JOB NAME> :  restrict selection to job name
        -ns              :  restrict list to non SUCCEEDED jobs
        -curr            :  Use in conjunction of -r (run now)  then
                            run_count, last_start_date, last_run_duration, and failure_count are not updated


        shed -l -u <SYSTEM> 
        shed -log -u <SYSTEM>  -ns
EOF
exit
}
# ------------------------------------------------------------------------------
ROWNUM=31
if [ -z "$1" ];then
   help
fi
USE_CURRENT_SESSION=TRUE

while [ -n "$1" ]
do
 case "$1" in
      -a ) req="ARG" ;;
      -l ) req=LIST ;;
    -log ) req=LOG ;;
   -drop ) req=DROP; JOB_NAME=$2;shift ;;
      -d ) req=DISABLE; JOB_NAME=$2;shift ;;
      -e ) req=ENABLE; JOB_NAME=$2;shift ;;
     -rj ) req=LIST_RUNNING_JOB;;
    -lss ) req=LSS ;;
     -rn ) ROWNUM=$2 ; shift ;;
      -h ) help ;;
      -r ) req=RUN_NOW;  JOB_NAME=$2;shift ;;
   -curr ) USE_CURRENT_SESSION=FALSE;;
   -ns   ) AND_NOT_SUCCEED=" and status <> 'SUCCEEDED' " ;;
      -o ) req=overview ;;
      -u ) OWNER=$2; shift ; 
            AND_OWNER="and owner = upper('$OWNER') " 
            AAND_OWNER="and a.owner = upper('$OWNER') " ;;
      -j ) JOB_NAME=$2; shift ;; 
      -v ) VERBOSE=TRUE ;;
      *  ) help ;;
 esac
 shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# -------------------------------------------------------------------------------------
if [ "$req" = "ARG" ];then
TITTLE="List program argument"
SQL="
col argument_name  for a20
col value          for a50
col owner      for a20
col job_name       for a28
col program_name   for a25
col argument_position for 99 head 'Pos'
set head on lines 190 pages 66 feed on

break on owner on job_name skip 1 on program_name on report

SELECT jobs.owner,
     jobs.JOB_NAME, jobs.program_name,args.argument_position, args.argument_name
     , args.value
  FROM dba_scheduler_jobs     jobs
     , dba_scheduler_programs prog
     , dba_scheduler_job_args args
 WHERE jobs.job_name          = args.job_name (+)
   AND jobs.owner             = args.owner (+)
   AND jobs.program_name      = prog.program_name
   AND jobs.program_owner     = prog.owner
   AND jobs.owner             = NVL(UPPER('$OWNER'), UPPER(jobs.owner))
   AND jobs.job_name          = NVL(UPPER('$JOB_NAME'), UPPER(jobs.job_name))
   and argument_name is not null
 ORDER BY jobs.owner , jobs.job_name, jobs.program_name, args.ARGUMENT_POSITION
/
"
# -------------------------------------------------------------------------------------
elif [ "$req" = "LIST_RUNNING_JOB" ];then
     TTITLE="List job running from scheduler"
    SQL="col SESSION_STAT_CPU format A16
col SESSION_SERIAL_NUM head 'Serial'
col ELAPSED_TIME format a16
prompt
select * from gv\$SCHEDULER_RUNNING_JOBS order by SESSION_ID;
prompt
select SESSION_ID, OWNER, JOB_NAME, JOB_SUBNAME,  ELAPSED_TIME, SLAVE_OS_PROCESS_ID
       from SYS.DBA_SCHEDULER_RUNNING_JOBS order by SESSION_ID;
prompt
select job_name,ENABLED, STATE, RUN_COUNT,FAILURE_COUNT,RETRY_COUNT, to_char(LAST_START_DATE,'MM/DD HH24:MI:SS') lsd,
       to_char(NEXT_RUN_DATE,'MM/DD HH24:MI:SS') Nrd from sys.dba_scheduler_jobs where STATE='RUNNING' order by 1,2;
prompt
prompt
"
  
# -------------------------------------------------------------------------------------
elif [ "$req" = "LOG" ];then
    if [ -n "$JOB_NAME" ];then
         AND_JOB="and job_name = upper('$JOB_NAME') " 
    fi
    SQL="select LOG_DATE,owner,JOB_NAME,OPERATION, STATUS-- , ADDITIONAL_INFO
         from  
           (select to_char(LOG_DATE,'YYYY/MM/DD HH24:MI:SS')LOG_DATE,owner,JOB_NAME,OPERATION, STATUS -- , ADDITIONAL_INFO
             from  DBA_SCHEDULER_JOB_LOG where 1=1 $AND_OWNER $AND_JOB $AND_NOT_SUCCEED order by LOG_DATE desc
) where ROWNUM<=$ROWNUM ;
"
elif [ "$req" = "overview" ];then
SQL="col SCHEDULE_NAME format a18
col WINDOW_NAME format a20
col SCHEDULE_NAME format a24
col PROGRAM_ACTION format a25
col REPEAT_INTERVAL format a55
col duration format a16
set lines 190 pagesize 66
select aaa.window_name, bbb.SCHEDULE_NAME, program_action, repeat_interval, duration
  from dba_scheduler_windows aaa,
       (
select WINDOW_GROUP_NAME, WINDOW_NAME, program_action, SCHEDULE_NAME
  from
(select WINDOW_GROUP_NAME, WINDOW_NAME from DBA_SCHEDULER_WINGROUP_MEMBERS ) aa,
(select program_action, SCHEDULE_NAME  from dba_scheduler_programs a, DBA_SCHEDULER_JOBS b where a.PROGRAM_NAME = b.program_name) bb
WHERE
  aa.WINDOW_GROUP_NAME=bb.SCHEDULE_NAME) bbb
where aaa.window_name=bbb.WINDOW_NAME ;
"
# -------------------------------------------------------------------------------------
elif [ "$req" = "RUN_NOW" ];then
if [ -z "$OWNER" ];then
   echo "I need an owner"
   exit
fi
SQL="set timing on
prompt doing now exec dbms_scheduler.run_job( '$OWNER.$JOB_NAME',$USE_CURRENT_SESSION);;
exec dbms_scheduler.run_job( '$OWNER.$JOB_NAME',$USE_CURRENT_SESSION);
"
# -------------------------------------------------------------------------------------
elif [ "$req" = "DISABLE" ];then
if [ -z "$OWNER" ];then
   echo "I need an owner"
   exit
fi
SQL="set verify on feed on
prompt Doing now : exec dbms_scheduler.disable( '$OWNER.$JOB_NAME') ;;
exec dbms_scheduler.disable( '$OWNER.$JOB_NAME');"
# -------------------------------------------------------------------------------------
elif [ "$req" = "ENABLE" ];then
if [ -z "$OWNER" ];then
   echo "I need an owner"
   exit
fi
SQL="exec dbms_scheduler.enable( '$OWNER.$JOB_NAME');"
# -------------------------------------------------------------------------------------
elif [ "$req" = "DROP" ];then
if [ -z "$OWNER" ];then
   echo "I need an owner"
   exit
fi
SQL="set verify on feed on
prompt doing now : exec dbms_scheduler.drop_job(job_name => '$OWNER.$JOB_NAME');;
exec dbms_scheduler.drop_job(job_name => '$OWNER.$JOB_NAME');"
echo "Will do : $SQL"
# -------------------------------------------------------------------------------------
elif [ "$req" = "LSS" ];then
   TTITLE='List scheduler schedule'
   SQL="col repeat_interval format a20
    col comments format a40
    select owner,SCHEDULE_NAME,to_char(start_date,'YYYY-MM-DD HH24:MI:SS') start_date, REPEAT_INTERVAL, COMMENTS 
           from DBA_SCHEDULER_SCHEDULES where 1=1 $AND_OWNER order by 1,2;"
# -------------------------------------------------------------------------------------
elif [ "$req" = "LIST" ];then
    TTITLE="List submited scheduled jobs"
   SQL="
prompt Schedule Name:
prompt ..............

select OWNER, schedule_name,JOB_NAME, 
               decode(JOB_TYPE, 'PLSQL_BLOCK','PLSQL',JOB_TYPE) Type, JOB_ACTION,
               REPEAT_INTERVAL from sys.dba_scheduler_jobs  
               where 1=1 $AND_OWNER order by 1,2; 
prompt Program Name:
prompt .............

  col program_action format a65
  col PROGRAM_NAME for a30
  select a.owner, b.job_name,a.program_name, a.program_action, a.enabled from DBA_SCHEDULER_PROGRAMS a, dba_scheduler_jobs b
                 where a.program_name = b.program_name (+) and a.owner = b.owner (+) $AAND_OWNER order by 1,2;
prompt
prompt Run Window:
prompt ...........

   select owner,job_name,ENABLED, STATE, RUN_COUNT,FAILURE_COUNT,RETRY_COUNT, to_char(LAST_START_DATE,'MM/DD HH24:MI:SS') lsd,
          to_char(LAST_RUN_DURATION,'MM-DD HH24:MI:SS') LAST_RUN_DURATION,
              to_char(NEXT_RUN_DATE,'MM/DD HH24:MI:SS') Nrd from sys.dba_scheduler_jobs where 1=1 $AND_OWNER order by 1,2;"
fi
# -------------------------------------------------------------------------------------

if [ "$VERBOSE" = "TRUE" ];then
   echo "$SQL"
fi

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66  linesize 100  heading off  embedded off pause off  verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       '$TTITLE  ' nline
from sys.dual
/
prompt
set embedded on heading on feedback off linesize 162 pagesize 0
col owner   format a18   heading 'Owner'
col operation format a10
col Status format a10
col JOB_NAME format a30
col SCHEDULE_NAME format a30
col TYPE format a5
col JOB_ACTION format a30
col program_action format a55
col STATE format a9
col RUN_COUNT format 999999 head "Run|count" justify c
col REPEAT_INTERVAL format a42
col nrd format a14 head "Next run date"
col lsd format a14 head "Last start date"
col failure_count format 99999 head "Fail|Count"
col retry_count format 99999 head "Retry|Count"
$SQL
exit
EOF

