#!/bin/ksh
# Program :  smenu_long_ops.ksh
# author  :  B. Polarski
# date    :  10 September 2005
#            13 September 2006 :  added option -m 
SILENCE=Y
# default conditional fields
ROWNUM="where rownum <60"
ORDER=" order by sid"
TRM=time_remaining
TRM_TITLE="Time|remain"
while true
do
      if [ -z "$1" ];then
         break
      fi
      case  $1 in
          -r ) ROWNUM="where rownum <=$2"
               shift ;;
          -f ) FILTER1=" sofar != totalwork "  ;;
          -m ) TRM=ELAPSED_SECONDS
               TRM_TITLE="Elapse|seconds";;
          -t ) ORDER=" order by to_char(start_time,'DD/MM HH24:MM:SS') desc ,sid desc" ;;
          -v ) set -xv ;;
          -x ) FILTER2=" sid = '"$2"' "
               ORDER=" order by sid, to_char(start_time,'DD/MM HH24:MM:SS') desc"
               shift ;;
          -h ) cat <<EOF

            slo -f          # Display if sofar is different than totalwork
            slo -x <sid>    # just for a given sid
            slo -t          # order by sid,start_time
                     -r <n> # limit display to <n> rows
                     -m     # replace field time_remain with elapsed_time

EOF
               exit ;;
         *) SINGLE_SID=" and s.sid = '$1' " ;;
        esac
        shift
done

if [ -n "$FILTER1" -o -n "$FILTER2" ];then
   ADD_WHERE="where "
   if [ -n "$FILTER1" -a -n "$FILTER2" ];then
      AND=" AND "
   fi
fi
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts


. $SBIN/scripts/passwd.env
. ${GET_PASSWD}
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi
sqlplus -s "$CONNECT_STRING" <<EOF

-- set linesize 80
-- ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   '    Page:' format 999 sql.pno skip 2
-- column nline newline
set pagesize 66
set termout on
set embedded off
set verify off
set heading off pause off

-- select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
--        'Username          -  '||USER  nline ,
--        'Long SQL : display status ' nline
-- from sys.dual
-- /
set head on pause off feed off
set linesize 190

prompt
column sid format 999999 head "Sid"
column hv format a15 head "Sql id"  justify c
column opname format A28 head "Operation"  justify c
column target format A28 head "Target"  justify c
column trm format 99999 head "$TRM_TITLE"  justify c
column units format A8 head "Target"  justify c
column message format A90 head "Message"  justify c
column start_time format A14 head "Start time" justify c
column mins_left format 99999 head "Minutes|left" justify c
column mins_busy format 99999 head "Minutes|run" justify c
SELECT  sid,  message,
        to_char(start_time,'DD/MM HH24:MI:SS') start_time, trm, hv, pct "% COMPLETE",
        floor(elapsed_seconds/60)   mins_busy , ceil(time_remaining/60)  mins_left
from (
SELECT  sid, message, time_remaining, elapsed_seconds,
        start_time, $TRM trm , sql_id hv, decode(TOTALWORK,0,0,round(SOFAR/TOTALWORK*100,2)) pct
        from v\$session_longops $ADD_WHERE $FILTER1 $AND $FILTER2 $ORDER
  ) $ROWNUM $ORDER_SID
/
prompt
EOF

        #start_time, $TRM trm , sql_hash_value hv, decode(TOTALWORK,0,round(SOFAR/TOTALWORK*100,2)) pct
