#!/bin/sh
# smenu_job.ksh
# All about jobs
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------------------------------------
function help
{
cat <<EOF

        jb  -ls                  # List submitted jobs
        jb  -lr                  # List running jobs
        jb  -r <id>              # Run a job. Use 'jb -ls' to get the job id
        jb  -remove <id>         # Remove a job

  -v : verbose
EOF
exit
}
# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------
#                                  Main
# -------------------------------------------------------------------------------------------------------------------

FIELD="  what proc, "
FIELD2="  priv_user                  secd, "
FIELD_HEADER="col proc format a50  heading 'Job'           word_wrapped "
FIELD_HEADER2="col secd format a10  heading 'Security'      trunc"

if [ -z "$1" ];then
   help
  
fi

while [ -n "$1" ]
do
 case "$1" in
    -ls ) ACTION="LIST" ; EXECUTE=YES ; TITTTLE="List submited jobs" ;;
    -lr ) ACTION="LIST_RUN" ; EXECUTE=YES ; TITTTLE="List ssubmited jobs" ;;
     -n ) FIELD="interval," ; FIELD_HEADER="col interval format a50 heading 'Interval'";;
     -t ) FIELD2="total_time," ; FIELD_HEADER2="col total_time format 999,999,999 heading 'Total time'" ;;
     -r ) ACTION="RUN"  ; ID=$2; shift ; TITTLE="Run a Job" ;;
     -u ) S_USER=$2 ; export S_USER ; shift ;;
     -v ) set -xv ;;
     -remove ) ACTION="REMOVE"  ; ID=$2; shift ; TITTLE="Run a Job" ;;
 esac
 shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# -------------------------------------------------------------------------------------------------------------------
if [ "$ACTION" = "LIST" ];then
      SQL="select job jid, log_user  subu, $FIELD2 $FIELD
              to_char(last_date,'DD/MM/YYYY') lsd,
              substr(last_sec,1,5)            lst,
              to_char(next_date,'DD/MM/YYYY') nrd,
              substr(next_sec,1,5)            nrt,
              failures                        fail,
              decode(broken,'Y','Y','N')      Broken 
from sys.dba_jobs;
prompt "
# -------------------------------------------------------------------------------------------------------------------
elif [ "$ACTION" = "REMOVE" ];then
if [ -z "$ID" ];then
   echo "No job to remove given"
   exit
fi
VAR=`sqlplus -s "$CONNECT_STRING" <<EOF
set pages 0 feed off
select SCHEMA_USER from dba_jobs where JOB = $ID  ;
EOF`
RET=`echo "$VAR" | tr -d '\r' | awk '{ print toupper($1)}'`
if $SBINS/yesno.sh "To delete job $ID " DO Y
   then
        if [ "$RET"  = 'SYS' ];then
           THE_I=''
        else
           THE_I='i'
        fi
        sqlplus -s "$CONNECT_STRING" <<EOF
        execute sys.dbms_${THE_I}job.remove($ID)
EOF
fi
exit
# -------------------------------------------------------------------------------------------------------------------
elif [ "$ACTION" = "RUN" ];then
    if [ -z "$ID"  ];then
        echo "No job id given. Use 'jb -ls' to get the job"
        exit
    fi
   if $SBINS/yesno.sh "To run job $ID " DO Y
   then
       sqlplus -s "$CONNECT_STRING" <<EOF
execute sys.dbms_ijob.run($ID)
EOF
       exit
    fi


# -------------------------------------------------------------------------------------------------------------------
elif [ "$ACTION" = "LIST_RUN" ];then

SQL="set feed on
select --+ ordered
  djr.sid                        sess,
  djr.job               jid,
  dj.log_user                    subu,
  dj.priv_user            secd,
  dj.what                        proc,
  to_char(djr.last_date,'DD/MM/YYYY') lsd,
  substr(djr.last_sec,1,5)       lst,
  to_char(djr.this_date,'DD/MM/YYYY') nrd,
  substr(djr.this_sec,1,5)       nrt,
  djr.failures  fail
from
  sys.dba_jobs dj,
  sys.dba_jobs_running djr
where
  djr.job = dj.job ; "
fi
# -------------------------------------------------------------------------------------------------------------------

if [ -n  "$VERBOSE" ];then
    echo "$SQL"
fi

if [ "$EXECUTE"  = "YES" ];then
sqlplus -s "$CONNECT_STRING" <<EOF
column host_name new_value hostname noprint ;
select host_name from v\$instance ;
ttitle skip 2 'MACHINE &hostname - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66  linesize 100  heading off  embedded off pause off  verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List Submitted Jobs  ' nline
from sys.dual
/
prompt
set embedded on
set heading on
set feedback off
set linesize 162 pagesize 0
col fail format 999  heading 'Errs'
col broken   format a3   heading 'Bro|ken'

col sess format 9999   heading 'Ses'
col jid  format 999999  heading 'Job|Id'
col subu format a10  heading 'Submitter'     trunc
col secd format a10  heading 'Security'      trunc
col proc format a30  heading 'Job'           word_wrapped
col lsd  format a10  heading 'Last|Ok|Date'
col lst  format a5   heading 'Last|Ok|Time'
col nrd  format a10  heading 'This|Run|Date'
col nrt  format a5   heading 'This|Run|Time'
col fail format 99 heading 'Err'

$FIELD_HEADER
$FIELD_HEADER2

$SQL

exit
EOF
fi
