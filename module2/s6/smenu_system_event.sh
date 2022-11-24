#!/bin/ksh 
# program : smenu_system_event.sh
# author  : B. Polarski
# date    : December 1999
#
ORDER=" order by pct desc"

function help
{
cat <<EOF
 

            Show System events figures (v\$system_event)

             sls
             sls -n  [ -c nn ] # list events by name and class
             sls -w            # order by total waits
             sls -t            # order by time waited
             sls -g <event>    #  show event histogram for a given event name
             sls -resp         # List events with their impact on the system response time
             sls -d <secs>     # Show events during n seconds
             sls -g <event> # list event histogram 


EOF
exit
}
if [ "$1" = "-h" ];then
   help
fi
while [ -n "$1" ]
do
  case "$1" in
      -d ) CHOICE=DELTA ; SECONDS=$2 ; shift ;;
      -w ) ORDER="order by total_waits desc" ;;
      -t ) ORDER="order by time_waited desc" ;;
      -g ) CHOICE=HISTO ;shift ; EVT="$@"; break;;
      -n ) CHOICE=NAME ;;
      -c ) CLASS=$2 ; shift ;;
      -s ) SECS=$2; shift ;;
      -v ) set -xv ;;
      -resp ) CHOICE=RESP ;;
       * ) help ;;
  esac
  shift
done

HOST=`hostname`
HOST=`echo $HOST | awk '{printf ("%-+15.15s",$1)}'`
SBINS=$SBIN/scripts

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi


if [ "$CHOICE" = "DELTA" ];then
SECONDS=${SECONDS:-1}
SQL="
   set linesize 120 pagesize 333 feed off head off
   set serveroutput on size 999999
   ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';
   declare
    type  TB_NUM     is table of  number INDEX BY  BINARY_INTEGER ;
    type  TB_EVENT  is table of  VARCHAR2(64) INDEX BY BINARY_INTEGER ;

    
  T_TOTAL_WAITS1            TB_NUM ;
  T_TIME_WAITED_MICRO1      TB_NUM ;
  T_TOTAL_TIMEOUTS1         TB_NUM ;

  T_TOTAL_WAITS2            TB_NUM ;
  T_TIME_WAITED_MICRO2      TB_NUM ;
  T_TOTAL_TIMEOUTS2         TB_NUM ;
  T_ID                      TB_NUM ;

  T_EVENT1   TB_EVENT ; 
  T_EVENT2   TB_EVENT ; 

  tsp1 timestamp ;
  cpt number  ;
  i number  ;
  v_db_time1 number ;
  v_db_time2 number ;
  v_db_time  number ;

  
  begin
     cpt:=1 ;
     for c in ( select EVENT, round(EVENT_ID/2679325) EVENT_ID, TOTAL_WAITS, TIME_WAITED_MICRO, TOTAL_TIMEOUTS
                       -- ,TOTAL_WAITS_FG, TIME_WAITED_MICRO_FG, TOTAL_TIMEOUTS_FG 
                       from v\$system_event order by event
              )
     loop
         T_EVENT1( c.EVENT_ID)                :=c.EVENT ;
         T_TOTAL_WAITS1( c.EVENT_ID)          :=c.TOTAL_WAITS ;
         T_TIME_WAITED_MICRO1( c.EVENT_ID)    :=c.TIME_WAITED_MICRO ;
         T_TOTAL_TIMEOUTS1( c.EVENT_ID)       :=c.TOTAL_TIMEOUTS ;
     end loop ;
     select value into v_db_time1 from V\$SYS_TIME_MODEL where stat_name = 'DB time' ;
     tsp1:=systimestamp ;
     dbms_lock.sleep($SECONDS) ;

     cpt:=1 ;
     for c in ( select EVENT, round(EVENT_ID/2679325) EVENT_ID, TOTAL_WAITS, TIME_WAITED_MICRO, TOTAL_TIMEOUTS
                       -- ,TOTAL_WAITS_FG, TIME_WAITED_MICRO_FG, TOTAL_TIMEOUTS_FG 
                       from v\$system_event order by event
              )
     loop
         T_ID(cpt)                            :=c.EVENT_ID ;
         cpt := cpt + 1 ;
         T_EVENT2( c.EVENT_ID)                :=c.EVENT ;
         T_TOTAL_WAITS2( c.EVENT_ID)          :=c.TOTAL_WAITS ;
         T_TIME_WAITED_MICRO2( c.EVENT_ID)    :=c.TIME_WAITED_MICRO ;
         T_TOTAL_TIMEOUTS2( c.EVENT_ID)       :=c.TOTAL_TIMEOUTS ;
     end loop ;
     select value into v_db_time2 from V\$SYS_TIME_MODEL where stat_name = 'DB time' ;
     v_db_time:=round((v_db_time2-v_db_time1)/1000000,1) ;

     DBMS_OUTPUT.PUT_LINE ('DB TIME =' ||to_char(v_db_time) ) ;
     DBMS_OUTPUT.PUT_LINE (chr(10)||'                                           Total      Total time     Avg time       Total   ' ); 
     DBMS_OUTPUT.PUT_LINE ('Event Name                              Total waits   waited (s)    Waited (s)   Timeout     ' ); 
     DBMS_OUTPUT.PUT_LINE ('--------------------------------------- ------------ ------------  ------------ ------------') ;
     for v in T_ID.first..T_ID.last
     loop
        i:=T_ID(v) ; 
        if (  T_EVENT2.exists(i) ) then
            if (  T_EVENT1.exists(i) ) then
               if ( ( T_TOTAL_WAITS2(i) - T_TOTAL_WAITS1(i) ) > 0   ) then 
                    dbms_output.put_line( rpad(T_EVENT1(i),40) 
                        || lpad(to_char(T_TOTAL_WAITS2(i) - T_TOTAL_WAITS1(i) ),12) || ' '
                        || lpad(to_char(round((T_TIME_WAITED_MICRO2(i) - T_TIME_WAITED_MICRO1(i))/1000000,2 )),12) || ' '
                        || lpad(to_char(round((
                                                (T_TIME_WAITED_MICRO2(i) - T_TIME_WAITED_MICRO1(i))/(T_TOTAL_WAITS2(i) - T_TOTAL_WAITS1(i))
                                               )/1000000,3 )),12) || ' '
                        || lpad(to_char(T_TOTAL_TIMEOUTS2(i) - T_TOTAL_TIMEOUTS2(i) ) ,12) || ' '
                    ) ;
                end if  ;
            end if ;
        end if ;
     end loop ;
  end ;
/
"
#echo "$SQL"

elif [ "$CHOICE" = "NAME" ];then
   if [ -n "$CLASS" ];then
       WHERE=" where wait_class# = $CLASS"
   fi
SQL="col NAME format a45
col wait_class# format 99 head 'id'
col WAIT_CLASS format a12
col PARAMETER1 format a20
col PARAMETER2 format a20
col PARAMETER3 format a20
set lines 157 pagesize 132
select NAME, WAIT_CLASS#, WAIT_CLASS, PARAMETER1, PARAMETER2, PARAMETER3 from v\$event_name $WHERE;"
echo $SQL
elif [ "$CHOICE" = "RESP" ];then
SQL="col tot_wait new_value tot_wait
col service_time new_value service_time
col response_time new_value response_time
col parse_time_cpu new_value parse_time_cpu
col recursive_cpu new_value recursive_cpu
col cpu_other  new_value cpu_other
set pagesize 66 con off SQLBL off head on
set lines 190
select  tot_wait, service_time, parse_time_cpu, recursive_cpu,
       (service_time + tot_wait) response_time, (service_time-parse_time_cpu-recursive_cpu) cpu_other
from
    (select  sum(time_waited) tot_wait from v\$system_event)
   ,(select value service_time from v\$sysstat where name = 'CPU used by this session')
   ,(select value parse_time_cpu from v\$sysstat where name = 'parse time cpu')
   ,(select value recursive_cpu from v\$sysstat where name = 'recursive cpu usage') ;

col impact   head 'Impact %'
column event format a45 head 'Event type'
column total_waits head 'Total  |Waits  '
column total_timeouts head 'Total  | Timeouts '
column time_waited format 9999999999.9 head ' Time (cs)|Waited  '
column average_wait format 99999999.9 head 'Average (ms)|Wait   '
col wait_class format a16

select
  a.event, total_waits $S total_waits, total_timeouts ,
   time_waited,  average_wait, a.wait_class, time_waited/&response_time*100 impact
from
  sys.v_\$system_event a
  where  a.wait_class !='Idle' order by impact ;

"
#--prompt system total time waited  : &tot_wait cs
#--prompt Service time              : &service_time
#--prompt Response time             : &response_time
#-- prompt CPU others                  &cpu_other

elif [ "$CHOICE" = "HISTO" ];then

if [ -z "$SECS" ];then
   SQL="set lines 150
col perc for a8 head 'Perc'
col wait_time_milli head 'Wait time (ms)|Category' justify c
col wait_count head Count for 99999999999
break on report 
comp sum label 'Total wait' of wait_count on report
with c as (select sum(wait_count) totwait from  v\$event_histogram WHERE  event = '$EVT' )
SELECT event, wait_time_milli, wait_count  ,  ' '|| to_char(round(wait_count/totwait*100,1))|| '%' as Perc
       FROM   v\$event_histogram , c
       WHERE  event = '$EVT' 
       ; "
fi
else # DEFAULT

SQL="with view_sum as (
select	sum(time_waited) total_time_waited
from v\$system_event
where event not in (
   'dispatcher timer',
    'lock element cleanup',
    'Null event',
    'parallel query dequeue wait',
    'parallel query idle wait - Slaves',
    'pipe get',
    'PL/SQL lock timer',
    'pmon timer',
    'rdbms ipc message',
    'slave wait',
    'smon timer',
    'SQL*Net break/reset to client',
    'SQL*Net message from client',
    'SQL*Net message to client',
    'SQL*Net more data to client',
    'virtual circuit status',
    'WMON goes to sleep'
)
AND
 event not like 'DFS%'
and
   event not like '%done%'
and
   event not like '%Idle%'
AND
 event not like 'KXFX%'
)
select event, total_waits, total_timeouts ,  
  trunc(time_waited/100) time_waited, 
   average_wait/100 average_wait,
  (time_waited/v.total_time_waited)*100 pct
from
  v\$system_event  e , view_sum v
where event not in (
   'dispatcher timer',
    'lock element cleanup',
    'Null event',
    'parallel query dequeue wait',
    'parallel query idle wait - Slaves',
    'pipe get',
    'PL/SQL lock timer',
    'pmon timer',
    'rdbms ipc message',
    'slave wait',
    'smon timer',
    'SQL*Net break/reset to client',
    'SQL*Net message from client',
    'SQL*Net message to client',
    'SQL*Net more data to client',
    'virtual circuit status',
    'WMON goes to sleep' )
AND event not like 'DFS%'
and event not like '%done%'
and event not like '%Idle%'
AND event not like 'KXFX%'
AND event not like '%idle%'
and time_waited/360000 >= 0.01 $ORDER ;
"
fi


# we do the work here

echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID  "
sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 80
column nline newline
set pagesize 66 termout on embedded off verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show System events figures (v\$system_event)' nline from sys.dual
/   
set head on pause off feed off linesize 132
column event format a56 head "Event type"
column total_waits head "Total number|of waits  "
column total_timeouts head "Total number |of timeouts "
column time_waited head " Time waited  | (secs)" justify c
column average_wait format 9990.9999 head "Average wait |(sec)" justify c
col pct format 990.99 head "% of| Waits"
$SQL
prompt
EOF

