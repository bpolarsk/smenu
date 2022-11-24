#!/bin/ksh
#-------------------------------------------------------------------------------
#-- Script:     smenu_ses_stat.ksh
#-- Author:     B. polarski
#-- Date  :     14/09/2006
#-------------------------------------------------------------------------------
#set -x
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINT=$SBIN/tmp
function help
{
cat <<EOF


        Show session statistics:
        -----------------------

        ses  <sid>                       # show all statistics values for v\$sesstat
        ses  <sid> -s                    # show all statistics values for v\$sesstat
        ses  <sid> -c <CLASS>            # show all values only for <CLASS> values=1,8,32,64,128
        ses  <sid> -rb                   # show effective usage of undo recreation per session

          Example :   ses 165 -c 1       # show all stats of class 1 for session 165

        ses  <sid> -d <sec> -c <CLASS>   # Give stats delta for -d <sec>
        ses  <sid> -d <sec> -tx -s -k    # show system transactions:  Transaction are defined here as just user commits
                                         # and user rollbacks.  This is in no way a TPC type measurement, but more rather
                                         # an atomic transaction measurement.
        ses  <sid> -de <sec> -c <CLASS>  # Event delta values for some seconds for a sessions
             -s  : first and second measurement are done without echo on
             -k  : Keep the two measurement files

       WARNING : if a session disconnect and is replaced by another new one with same sid, you will see negative number
EOF
exit
}
if [ "$1"  = "-h" ];then
    help
fi
ACTION=DEFAULT
SILENT=FALSE
KEEP=FALSE

while [ -n "$1" ]
do
  case "$1" in
      -tx ) ACTION=DIFF ; FILTER=" and NAME IN ('user commits','user rollbacks') ";;
       -d ) ACTION=DIFF ; SLEEP_TIME=$2 ;shift;;
       -de ) ACTION=EVENT ; SLEEP_TIME=$2 ;shift;;
       -c ) FILTER="and CLASS=$2"; shift ;;
       -s ) SILENT="TRUE";;
       -k ) KEEP="TRUE";;
       -rb ) ACTION="RBLS";;
       -h ) help ;;
       -v ) VERBOSE=TRUE ; set -xv;;
        * ) sess_sid=$1;;
  esac
  shift
done
if [ -n "$sess_sid" ];then
    WHERE_SID="sid = '$sess_sid' and "
fi

TTITLE="Session $sess_sid statistics"
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi

#..........................................................................
if [ "$ACTION" = "RBLS" ];then 

SQL="col created head 'CR blocks created'
col Undo_applied head 'data blocks consistent reads | undo records applied'
col perc head 'Efficiency(%)'
select sid , undo_applied, created,  decode (undo_applied, 0, 0 , round(created/undo_applied*100,1)) perc from
(
select  sid,
   max(case name
     when  'CR blocks created' then value
     end) Created,
   max(case name
   when 'data blocks consistent reads - undo records applied' then value
    end) Undo_applied
  from (
           select  sid, sn.name, ss.value from     
             v\$sesstat       ss,
             v\$statname sn 
           where $WHERE_SID sn.statistic# = ss.statistic# 
              and name in ('CR blocks created','data blocks consistent reads - undo records applied') and value > 0
) group by sid
);
"
#..........................................................................
elif [ "$ACTION" = "EVENT" ];then 
$SETXV
sqlplus -s "$CONNECT_STRING"    <<EOF
set linesize 120 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 --type s  is table of  number INDEX BY binary_integer ;
 --type t  is table of  varchar2(64) INDEX BY binary_integer ;
 type s  is table of  number INDEX BY varchar2(20) ;
 type t  is table of  varchar2(64) INDEX BY varchar2(20) ;
  v1 s ;
  v2 s;
  t1 t;
  t2 t;
  v_var varchar2(20) ;
begin
dbms_output.put_line('First reading');
   for c in ( select mod(ora_hash(event),1048576) id, time_waited value, event name from v\$session_event
                     where sid = $sess_sid  order by mod(ora_hash(event),1048576) )
   loop
       v1(to_char(c.id)):=c.value;
       t1(to_char(c.id)):=c.name;
   end loop;

dbms_output.put_line('sleeping ');
   dbms_lock.sleep($SLEEP_TIME);

dbms_output.put_line('second reading');
   for c in ( select mod(ora_hash(event),1048576) id, time_waited value, event name from v\$session_event
                     where sid = $sess_sid  order by mod(ora_hash(event),1048576) )
   loop
       v2(to_char(c.id)):=c.value;
       t2(to_char(c.id)):=c.name;
       --DBMS_OUTPUT.PUT_LINE( 'id=' ||to_char(c.id) || ' name=' ||c.name || ' val=' || to_char(c.value)  );
   end loop;
   DBMS_OUTPUT.PUT_LINE ('Name                                       Diff         Value1        Value2' );
   DBMS_OUTPUT.PUT_LINE ('------------------------------------------ ------------ ------------- -----------') ;

   v_var := v2.FIRST;
   WHILE v_var IS NOT NULL LOOP
          if (v2.exists(v_var)  ) then
                if  v2(v_var) != v1(v_var) then
                    DBMS_OUTPUT.PUT_LINE(rpad(t2(v_var),44,' ') || rpad(to_char(v2(v_var)-v1(v_var)),12,' ')
                                          || rpad(to_char(v1(v_var)),12,' ') || '  ' || to_char(v2(v_var)) );
                end if ;
           else
                   DBMS_OUTPUT.PUT_LINE(rpad(t2(v_var),44,' ') || rpad(to_char(v2(v_var)),12,' ')|| '0           ' || '  ' || to_char(v2(v_var)) );
           end if ;
           v_var:=v1.next(v_var);
    end loop ;
end ;
/
EOF
exit

#..........................................................................
elif [ "$ACTION" = "DIFF" ];then 
$SETXV
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
begin
   for c in ( select a.statistic#, value, name from v\$sesstat a, v\$statname b 
                     where sid = $sess_sid and a.statistic#=b.statistic# and value > 0 $FILTER order by 1  )
   loop
       v1(c.statistic#):=c.value;
       t1(c.statistic#):=c.name;
   end loop;
   dbms_lock.sleep($SLEEP_TIME);

   for c in ( select a.statistic#, value, name from v\$sesstat a, v\$statname b 
                     where sid = $sess_sid and a.statistic#=b.statistic# and value > 0 $FILTER order by 1  )
   loop
       v2(c.statistic#):=c.value;
       t2(c.statistic#):=c.name;
   end loop;
   DBMS_OUTPUT.PUT_LINE ('Name                                       Diff         Value1        Value2' );
   DBMS_OUTPUT.PUT_LINE ('------------------------------------------ ------------ ------------- -----------') ;
 
    FOR i in v2.FIRST .. v2.LAST
    LOOP
        if (v2.exists(i)  ) then
            if (v1.exists(i)  ) then
                if  v2(i) != v1(i) then
                    DBMS_OUTPUT.PUT_LINE(rpad(t2(i),44,' ') || rpad(to_char(v2(i)-v1(i)),12,' ')|| rpad(to_char(v1(i)),12,' ') || '  ' || to_char(v2(i)) );
                end if ;
            else
                   DBMS_OUTPUT.PUT_LINE(rpad(t2(i),44,' ') || rpad(to_char(v2(i)),12,' ')|| '0           ' || '  ' || to_char(v2(i)) );
            end if ;
        end if ;
    end loop ;
end ;
/
EOF
exit
#..........................................................................
elif  [ "$ACTION" = "DEFAULT" ];then
  SQL="set pause on
       select class,name,value from v\$sesstat a,v\$statname b
       where sid = '$sess_sid' and value > 0 and a.statistic# = b.statistic# $FILTER
       order by class,name,value ;"
fi
#..........................................................................
#  Execute SQL
#..........................................................................
sqlplus -s "$CONNECT_STRING"   <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 termout on embedded on verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  ' ||USER  , '$TTITLE (help: ses -h)' from sys.dual
/
set head on

set pages 999 lines 80
column name heading 'Name'             format a51
column value format 999999999999999
$SQL
EOF

