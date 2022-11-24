#!/bin/ksh
#-------------------------------------------------------------------------------
#-- Script:     smenu_sys_stat.ksh
#-- Author:     B. polarski
#-- Date  :     12/09/2006
#-------------------------------------------------------------------------------
# set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINT=$SBIN/tmp
function help
{
cat <<EOF


        Show system statistics:
        -----------------------

        sys -l                         # show all values for system stats
        sys -c <CLASS>                 # show all values only for <CLASS> values=1,8,32,64,128
        sys -d <sec> -c <CLASS>        # Give stats delta for -d <sec>
                     -p <partial name> # show all stats related to this partial name
        sys -d <sec> [-tx]             # show system transactions:  Transaction are defined here as just user commits
                                       # and user rollbacks.  This is in no way a TPC type measurement, but more rather
                                       # an atomic transaction measurement.
        sys -d <sec> -redo             # measure the time to write a coomit (redo write time / user commit)
        sys -d <sec> -cle              # show system class event delta
        sys -rb                        # Show system CR blocks reconstruct from undo performance
        sys -d <sec> -g <event>        # Show the histogram of <event> taken during <sec> seconds
        sys -w                         # System waitstat figures (v\$waitstat)
        sys -io                        # System avg waits on Sequential and Scattered reads
        sys -ls "<stat name>" -b <snap_id> -e <snap_id> # Show Stat value between 2 snap id. use sys -l to cut & paste name




EOF
exit
}
if [ -z "$1" ];then
    help
    exit
fi
REDO_MEAS=FALSE
ACTION=DEFAULT 
while [ -n "$1" ]
do
  case "$1" in
       -b ) SNAP1=$2 ; shift ;;
       -e ) SNAP2=$2 ; shift ;;
      -ls ) ACTION=AWR_STAT ; STAT_NAME="$2" ; shift ;;
       -l ) ACTION=DEFAULT ;;
       -c ) FILTER="and a.CLASS=$2"; shift ;;
       -d ) ACTION=DIFF ; SLEEP_TIME=$2 ;shift;;
     -cle ) ACTION=DIFF_CLASS ;;
      -io ) ACTION=IO ;;
       -p ) FILTER="and a.name like '%$2%'"; shift ;;
      -tx ) ACTION=DIFF ; FILTER=" and a.NAME IN ('user commits','user rollbacks') ";;
    -redo ) ACTION=DIFF ; FILTER=" and a.NAME IN ('user commits','redo write time') "; REDO_MEAS=TRUE;;
       -g ) ACTION=DIFF_HISTO; shift ;EVT=$@; break ;;
      -rb ) ACTION=RBLS ;;
       -w ) ACTION=WAITSTAT ;;
       -v ) SETXV=DEBUG; set -x ;;
       -h ) help ;;
  esac
  shift
done

# cancel ACTION=DIFF if -g has been selectioned. We will use ACTION_HISTO
if [ -n "$DIFF_HISTO" ];then
     unset ACTION
fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi
# .........................................................
if  [ "$ACTION" = "AWR_STAT" ];then
    TITTLE="Show System stats values from AWR"
    if [ -z "$SNAP1" ];then
        echo "I need a begin snap : use aw -l to list snaps.."
        exit
    fi
    if [ -z "$SNAP2" ];then
       SNAP2=`expr $SNAP1 + 1`
    fi
SQL="set head on pause off feed off
set lines 190 pages 999

col instance_number for 99 head 'In|st' justify l
col snap_id for 999999 head 'Snap|id' justify c
col stat_name for a40
col value for 9999999999999 head 'Value' justify c
col per_secs head 'Per|second' for 999999999

comp sum of value , secs on report 
break on instance_number on stat_name on report

select INSTANCE_NUMBER,
       SNAP_ID, to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss') snap_begin
      , STAT_NAME, value, secs, round(value/decode(secs,0,1,secs),0) per_secs 
from (
        select x.SNAP_ID, x.INSTANCE_NUMBER, STAT_NAME, value-lvalue value,BEGIN_INTERVAL_TIME,
         round(( to_number(extract(second from END_INTERVAL_TIME)) +
              to_number(extract(minute from END_INTERVAL_TIME)) * 60 + 
              to_number(extract(hour from END_INTERVAL_TIME))   * 60 * 60 + 
              to_number(extract(day from END_INTERVAL_TIME))  * 60 * 60* 24 ) -
          (
          to_number(extract(second from BEGIN_INTERVAL_TIME)) +
              to_number(extract(minute from BEGIN_INTERVAL_TIME )) * 60 + 
              to_number(extract(hour from BEGIN_INTERVAL_TIME))   * 60 * 60 + 
              to_number(extract(day from BEGIN_INTERVAL_TIME))  * 60 * 60* 24),0)  secs
        from 
        (
          select SNAP_ID as SNAP_ID, INSTANCE_NUMBER, STAT_NAME, value ,  
                lag(value) over ( order by snap_id ) lvalue 
          from SYS.DBA_HIST_SYSSTAT
          where snap_id >= $SNAP1 and snap_id <= $SNAP2 
                and stat_name = '$STAT_NAME'
        ) x,
        sys.wrm\$_snapshot a
       where 
              lvalue is not null
          and x.snap_id = a.snap_id
         )
order by snap_id desc
/
"
# .........................................................
elif  [ "$ACTION" = "IO" ];then
    TITTLE="Show System avg waits on Sequential and Scattered reads"
SQL="set head on pause off feed off
set linesize 80
select event, average_wait from v\$system_event where event like 'db file s%read' ;
"
# .........................................................
elif  [ "$ACTION" = "WAITSTAT" ];then
    TITTLE="Show System waitstat figures (v\$waitstat)"
SQL="set head on pause off feed off
set linesize 80

column wait head "Class"
column count head "Count"
column time head "Time"

select
 rownum as class#, class, count , Time
from
  sys.v_\$waitstat ;
"
# .........................................................
elif  [ "$ACTION" = "RBLS" ];then
SQL="
col created head 'CR blocks created'
col Undo_applied head 'data blocks consistent reads | undo records applied'
select undo_applied, created,  decode (undo_applied, 0, 0 , round(created/undo_applied*100,1)) perc 
from ( select
           max(case name
                    when  'CR blocks created' then value
           end) Created,
           max(case name
                    when 'data blocks consistent reads - undo records applied' then value
            end) Undo_applied
        from ( select  name, value from v\$sysstat 
               where   name in ('CR blocks created','data blocks consistent reads - undo records applied') and value > 0
             )
     )
/
"
# .........................................................
elif  [ "$ACTION" = "DIFF_CLASS" ];then
   VERS=`$SBINS/smenu_get_ora_version.sh`
   if [ $VERS -gt 10 ];then
        TIW_FG1="TIW_FG1 (c.WAIT_CLASS#):= c.TIME_WAITS_FG;"
        TIW_FG2="TIW_FG2 (c.WAIT_CLASS#):= c.TIME_WAITS_FG;"
        COL11R2=",TIME_WAITED_FG"
        PRINT11A="||  rpad(to_char(TIW_FG2(i)-TIW_FG1(i)),13,' ')|| rpad(to_char(TIW_FG1(i)),14,' ') ||  to_char(TIW_FG1(i))  "
        PRINT11B="rpad('0',13,' ')|| rpad(to_char(TIW_FG1(i)),14,' ') ||  to_char(TIW_FG2(i))  "
        HEAD11="FG wait1    FG wait2 "
        LINE11="----------- ------------"
   fi
echo "MACHINE $HOSTNAME - ORACLE_SID : $ORACLE_SID                   Page: 1"
echo "Show system class wait "  
SLEEP_TIME=${SLEEP_TIME:-1}
#cat    <<EOF
sqlplus -s "$CONNECT_STRING"    <<EOF
set linesize 120 pagesize 333 feed off head off
set serveroutput on size 999999
declare
  type  NUM     is table of  number INDEX BY  BINARY_INTEGER ;
  type  TTITLE  is table of  VARCHAR2(64) INDEX BY BINARY_INTEGER ;

  TIW1     num ;
  TIW2     num ;

  TOW1     num ;
  TOW2     num ;

  TIW_FG1    num ;
  TIW_FG2   num ;

  TTYPE     TTITLE ;
  tsp1 timestamp ;

  -- TIW_FG2  num ;
  -- TIW_FG1  num ;

begin
   for c in ( select WAIT_CLASS#, WAIT_CLASS  , TIME_WAITED,  TOTAL_WAITS $COLR11R2
                     from v\$system_wait_class WHERE wait_class <> 'Idle' )
   loop
       TIW1 (c.WAIT_CLASS#):= c.TIME_WAITED;
       TOW1 (c.WAIT_CLASS#):= c.TOTAL_WAITS;
       TTYPE(c.WAIT_CLASS#):= c.WAIT_CLASS ;
       $TIW_FG1
   end loop;
   tsp1:=systimestamp ;

   sys.dbms_lock.sleep($SLEEP_TIME);
   for c in ( select WAIT_CLASS#, WAIT_CLASS , TIME_WAITED,   TOTAL_WAITS $COLR11R2
                     from v\$system_wait_class WHERE wait_class <> 'Idle' )
   loop
       TIW2 (c.WAIT_CLASS#):= c.TIME_WAITED;
       TOW2 (c.WAIT_CLASS#):= c.TOTAL_WAITS;
       TTYPE(c.WAIT_CLASS#):= c.WAIT_CLASS ;
       $TIW_FG2
   end loop;

   dbms_output.put_line  (chr(10)||'Sample duration : ' || to_char(tsp1-systimestamp,'SS')|| chr(10) );
   DBMS_OUTPUT.PUT_LINE ('Wait category (ms)              Diff waited  Time Waited1 Time Waited2 Diff count   Total Waited1 Total Waited2 $HEAD11' );
   DBMS_OUTPUT.PUT_LINE ('------------------------------  ------------ ------------ ------------ ------------ ------------- ------------- $LINE11') ;
   FOR i in TIW2.FIRST .. TIW2.LAST
   LOOP
        if (TIW2.exists(i)  ) then
            if (TIW1.exists(i)  ) then
                if  TIW2(i) != TIW1(i) then
                    DBMS_OUTPUT.PUT_LINE(
                           rpad(to_char(TTYPE(i)),32,' ')||  rpad(to_char(TIW2(i)-TIW1(i)),13,' ')|| rpad(to_char(TIW1(i)),13,' ') 
                           ||  rpad(to_char(TIW2(i)),13,' ') ||
                           rpad(to_char(TOW2(i)-TOW1(i)),13,' ')|| rpad(to_char(TOW1(i)),14,' ') ||  rpad(to_char(TOW2(i))  ,13,' ')
                           $PRINT11A );
                 else
                    DBMS_OUTPUT.PUT_LINE(rpad(to_char(TTYPE(i)),32,' ')||  rpad('0',13,' ')|| rpad(to_char(TIW1(i)),13,' ') 
                                         ||  rpad(to_char(TIW2(i)),13,' ') ||
                                         rpad('0',13,' ')|| rpad(to_char(TOW1(i)),14,' ') ||   rpad(to_char(TOW2(i)),13,' ')
                                         $PRINT11B );
                end if ;
            end if ;
        end if ;
    end loop ;
end ;
/
EOF
exit

# .........................................................
elif  [ "$ACTION" = "DIFF_HISTO" ];then
echo "MACHINE $HOSTNAME - ORACLE_SID : $ORACLE_SID                   Page: 1"
echo "Show histogram for event : $EVT   "  
SLEEP_TIME=${SLEEP_TIME:-1}
sqlplus -s "$CONNECT_STRING"    <<EOF
set linesize 120 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 type  num is table of  number INDEX BY BINARY_INTEGER;
 type  string  is table of  varchar2(64) INDEX BY BINARY_INTEGER;
  beg_value  num ;
  end_value  num;
  tsp1 timestamp ;


begin
   for c in ( select wait_time_milli, wait_count value from v\$event_histogram where event = '$EVT' )
   loop
       beg_value(c.wait_time_milli):=c.value;
   end loop;
   tsp1:=systimestamp ;

   sys.dbms_lock.sleep($SLEEP_TIME);
   for c in ( select wait_time_milli, wait_count value from v\$event_histogram where event = '$EVT' )
   loop
       end_value(c.wait_time_milli):=c.value;
   end loop;

   dbms_output.put_line  (chr(10)||'Sample duration : ' || to_char(tsp1-systimestamp,'SS')|| chr(10) );
   DBMS_OUTPUT.PUT_LINE (' Wait category (ms)                                            Diff         Value1        Value2' );
   DBMS_OUTPUT.PUT_LINE ('----------------------------------------------------------  ------------ ------------- -----------') ;
   FOR i in end_Value.FIRST .. end_value.LAST
   LOOP
        if (end_value.exists(i)  ) then
            if (beg_value.exists(i)  ) then
                if  end_value(i) != beg_value(i) then
                    DBMS_OUTPUT.PUT_LINE(rpad(to_char(i),65,' ')||  rpad(to_char(end_value(i)-beg_value(i)),9,' ')|| rpad(to_char(beg_value(i)),13,' ') ||  to_char(end_value(i)) );
                 else
                --   DBMS_OUTPUT.PUT_LINE( rpad(to_char(end_value(i)),12,' ')|| '0           ' || '  ' || to_char(end_value(i)) );
                    DBMS_OUTPUT.PUT_LINE(rpad(to_char(i),65,' ')||  rpad('0',9,' ')|| rpad(to_char(beg_value(i)),13,' ') ||  to_char(end_value(i)) );
                end if ;
            end if ;
        end if ;
    end loop ;
end ;
/
EOF
exit

# .........................................................
elif  [ "$ACTION" = "DIFF" ];then

# 
# 12-Feb-2008
# nice usage of ref cursor but false as bulk collect does not respect the sort and the indices of the PL/SQL table end differents.
# I keep howver the code here for future revisit
# beneath the commented code is a version with manual key assign. 
# Note : it is possible to sort PL/SQL table using INDEX by VARCHAR2(n) but this does not alloca bulk collect
#sqlplus -s "$CONNECT_STRING" <<EOF
#set linesize 120 pagesize 333 feed off head off
#set serveroutput on size 999999
#
#variable bef refcursor
#variable aft refcursor
#
#declare
#
# type s  is table of  number INDEX BY BINARY_INTEGER;
# type t  is table of  varchar2(64) INDEX BY BINARY_INTEGER;
#  s1 s ;
#  v1 s ;
#  s2 s;
#  v2 s;
#  t1 t;
#  t2 t;
#begin
#
#    open :bef
#          for select a.statistic#, value, b.name from v\$sysstat a, v\$statname b where a.statistic#=b.statistic# and value > 0 $FILTER
#          order by 1;
#    fetch :bef bulk collect into s1 ,v1, t1;
#
#    dbms_lock.sleep($SLEEP_TIME) ;
#
#    open :aft
#          for select a.statistic#, value, b.name from v\$sysstat a, v\$statname b where  a.statistic#=b.statistic# and value > 0 $FILTER
#          order by 1;
#    fetch :aft bulk collect into s2 ,v2,t2;
#    DBMS_OUTPUT.PUT_LINE ('Name                             Diff          Value1        Value2' );
#    DBMS_OUTPUT.PUT_LINE ('-------------------------------- ------------- ------------- -----------') ;
#    FOR i in s1.FIRST .. s1.LAST
#    LOOP
#
#      if s1(i) = s2(i) and v2(i) != v1(i) then
#      DBMS_OUTPUT.PUT_LINE(rpad(t2(i),34,' ') || rpad(to_char(v2(i)-v1(i)),12,' ')|| rpad(to_char(v1(i)),12,' ') || '  ' || to_char(v2(i)) );
#      end if ;
#    end loop ;
#end ;
#/
#EOF
SLEEP_TIME=${SLEEP_TIME:-1}
sqlplus -s "$CONNECT_STRING"    <<EOF
set linesize 120 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 type s  is table of  number INDEX BY BINARY_INTEGER;
 type t  is table of  varchar2(64) INDEX BY BINARY_INTEGER;
  v1 s ;
  v2 s;
  t1 t;
  t2 t;
  
  -- added for -redo option
  type  time_wait_rec is record (timw number, tot_waits number);
  redo_meas boolean:=$REDO_MEAS;
  user_commits number;
  lg1  time_wait_rec;
  lg2  time_wait_rec;
  tsp1 timestamp ;
  function ret_log_w  return time_wait_rec
  is
    lrec time_wait_rec ;
    begin
        select
               nvl(se.time_waited_micro,0) + nvl(b.cpt,0), total_waits into lrec.timw, lrec.tot_waits
        from v\$system_event se ,
             ( select sum(cpt) cpt from ( select    /* units here are given in micro seconds */
                     case when WAIT_TIME = 0 then SECONDS_IN_WAIT
                          when wait_time > 0 then SECONDS_IN_WAIT -( WAIT_TIME / 100)
                          else 0
                      end as cpt
               from v\$session_wait where event = 'log file_sync' and state = 'WAITING'
             ) ) b
        where se.event='log file sync' ;
        return lrec ;
    end ;
   
begin
   for c in ( select a.statistic#, a.value, b.name from v\$sysstat a, v\$statname b
                     where  a.statistic#=b.statistic# and a.value > 0 $FILTER order by 1  )
   loop
       v1(c.statistic#):=c.value;
       t1(c.statistic#):=c.name;
   end loop;
   if ( redo_meas = TRUE ) then
         lg1:=ret_log_w();
   end if ;
   tsp1:=systimestamp ;
   sys.dbms_lock.sleep($SLEEP_TIME);

   for c in ( select a.statistic#, a.value, b.name from v\$sysstat a, v\$statname b
                     where a.statistic#=b.statistic# and a.value > 0 $FILTER order by 1  )
   loop
       v2(c.statistic#):=c.value;
       t2(c.statistic#):=c.name;
   end loop;
   if ( redo_meas = TRUE ) then
         lg2:=ret_log_w();
   end if ;
   dbms_output.put_line  (chr(10)||'Sample duration : ' || to_char(tsp1-systimestamp,'SS')|| chr(10) ); 
   DBMS_OUTPUT.PUT_LINE ('Name                                                        Diff         Value1        Value2' );
   DBMS_OUTPUT.PUT_LINE ('----------------------------------------------------------  ------------ ------------- -----------') ;
   if ( redo_meas = TRUE ) then
        DBMS_OUTPUT.PUT_LINE ('Log file Sync  (wait in micro)                              '|| rpad(to_char(lg2.timw-lg1.timw),13) || rpad(to_char(lg1.timw),13) || rpad(to_char(lg2.timw),12) );
   end if ;
   FOR i in v2.FIRST .. v2.LAST
    LOOP
        if (v2.exists(i)  ) then
            if (v1.exists(i)  ) then
                if  v2(i) != v1(i) then
                    DBMS_OUTPUT.PUT_LINE(rpad(t2(i),60,' ')||  rpad(to_char(v2(i)-v1(i)),13,' ')|| rpad(to_char(v1(i)),13,' ') ||  to_char(v2(i)) );
                     if ( redo_meas = TRUE ) then
                          if ( t2(i) = 'user commits' ) then
                               user_commits :=v2(i)-v1(i);
                          end if ;
                          if ( t2(i) = 'redo write time' ) then
                               if ( v2(i) > v1(i) ) then 
                                    if (user_commits>0) then
                                       DBMS_OUTPUT.PUT_LINE(chr(10)||'Performance                      := 0' || substr(to_char( (v2(i) - v1(i))/user_commits),1,5) || ' ms per user commits of ''redo write time''');
                                       DBMS_OUTPUT.PUT_LINE(' Total Log file sync              := '|| to_char(lg2.tot_waits-lg1.tot_waits) );
                                       if ( lg2.tot_waits-lg1.tot_waits > 0 ) then
                                          DBMS_OUTPUT.PUT_LINE(' Average time per Log file sync   := '|| substr(to_char((lg2.timw-lg1.timw)/1000/(lg2.tot_waits-lg1.tot_waits)),1,5) || ' ms' );
                                       end if ;
                                       DBMS_OUTPUT.PUT_LINE(' Total time for Log file sync     := '|| to_char((lg2.timw-lg1.timw)/1000) || ' ms' ||chr(10));
                                    end if;
                               end if;
                          end if ;
                     end if ; 
                end if ;
            else
                   DBMS_OUTPUT.PUT_LINE(rpad(t2(i),60,' ') || ' '|| rpad(to_char(v2(i)),12,' ')|| '0           ' || '  ' || to_char(v2(i)) );
            end if ;
        end if ;
    end loop ;
end ;
/
EOF
exit

elif  [ "$ACTION" = "DEFAULT" ];then
  SQL="set pause on
select class,name,value from v\$sysstat a  where value > 0 $FILTER order by class,name,value ;"
fi

if [ -n "$SETXV" ];then
   echo "$SQL"
fi
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  , '$TITTLE' from sys.dual
/
set head on

set pages 999
set lines 124
column name heading 'Name'             format a51
column value format 99,999,9999,999,999,999,999
$SQL
EOF

