#!/bin/sh
# set -xv
# author  : B. Polarski
# program : smenu_stream_propagation.ksh
# date    : 16 Decembre 2005
#           03 October 2007   Add Queue to queue (-lq)
#           15 October 2007   Added stats from stream 10G healthcheck from metatlink, just for conveniance
#           20 October 2007   Added list propagation schedule
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------µ
#--       DBMS_AQADM.ALTER_PROPAGATION_SCHEDULE(
#--          queue_name        => '&&ApplSchema._strms_q',
#--          destination       => '@&&RemoteDBTNSName',
#--          latency           => NewParamVal,
#--          destination_queue => '&&ApplSchema._strms_q');
#  EXEC DBMS_AQADM.ALTER_SCHEDULE(queue_name,destination,latency=>1);

function help
{

  cat <<EOF

 Streams Propagation:

       prop -l | -create | -stop | -start  | -drop
            -destq <dest queue> -sourceq <source queue> -pn <Propagation name> -dblk <DB link> | -trace
       prop -lat <ss>  -pn <Propagation name> [ -adm <STREAM ADMIN USER> ]
       prop -s | -r  | -lr | -o <REMOTE DB> | -droprs <propagation>
       prop -d <sec> [-n <repeat_count>]


          -l : List propagation process                           -u : owner of the propagation
         -lr : List propagations rules                           -lc : List schedule propagation
         -lq : propagation queue to queues correspondancies       -s : Show statitics for propagations sender
          -r : Show statitics for propagations receiver         -rcr : Drop and recreate propagation with same ruleset
        -lat : Set the propagation latency (in seconds)          -pn : Name of the propagation
     -create : Create propagation process                        -qn : Name of the queue
       -drop : Drop propagation process                       -destq : Name of the destination queue
       -stop : stop propagation                                -dblk : database link to use with propagation queue
      -start : start propagation                            -sourceq : Name of the source queue
      -check : check propagation is possible                      -v : verbose
     -droprs : Drop propagation rule set                          -d : propagation traffic during n seconds
          -o : Show overal picture for propagation (status and figures)

      Add  : -trace to set events 24024 before starting the propagation

  Create a propagation queue   :  prop -create -u <OWNER> -pn <PROPAGATION NAME> -sourceq <QUEUE> -destq <QUEUE> -dblk <DATABASE LINK>
  prop Overal image            :  prop -o <REMOTE DB (TNS ENTRY)
  Start a propagation queue    :  prop -start <PROPAGATION NAME> [-u <OWNER> only if not STRMADMIN]  -trace
  Stop  a propagation queue    :  prop -stop  <PROPAGATION NAME> [-u <OWNER> only if not STRMADMIN]
  Drop  a propagation queue    :  prop -drop  <PROPAGATION NAME> [-u <OWNER> only if not STRMADMIN]
  recreate propagation         :  prop -rcr -u  <OWNER> -pn <PROPAGATION NAME>
  Set the propagation latency  :  prop -lat <ss>  -pn <PROPAGATION NAME>  [ -adm <STREAM ADMIN USER> only if not STRMADMIN ]
 check propagation is possible :  prop -check -u <OWNER> -pn <PROPAGATION NAME> -destq <QUEUE> | -u2 <OWNER_AT_DEST> -dblk <DB_LINK>
                                    (-u2 only if owner is # from -u )
  Drop propagation rules set   :  prop -droprs <PROPAGATION NAME>
  Traffic for all propagations :  prop -d 4 -n 6        # takes 6 delta of 4 secs each

    Stream administrator admin and his password can be deduced by smenu if you defined one for this instance
    in SM/3.8 ortherwise it will try to default to STRMADMIN/STRMADMIN


EOF

exit
}
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, '$TTITLE (prop -h for help)' nline
from sys.dual
/
set head on
col rsn format A28 head "Rule Set name"
col rn format A30 head "Rule name"
col rt format A64 head "Rule text"

col d_dblk format A40 head 'Destination dblink'
col nams format A41 head 'Source queue'
col namd format A66 head 'Remote queue'
col prop format A40 head 'Propagation name '
col rsname format A20 head 'Rule set name'
COLUMN TOTAL_TIME HEADING 'Total Time Executing|in Seconds' FORMAT 999999
COLUMN TOTAL_NUMBER HEADING 'Total Events Propagated' FORMAT 999999999
COLUMN TOTAL_BYTES HEADING 'Total mb| Propagated' FORMAT 9999999999
COL PROPAGATION_NAME format a26
COL SOURCE_QUEUE_NAME format a34 head "Source| queue name" justify c
COL DESTINATION_QUEUE_NAME format a24 head "Destination| queue name" justify c
col QUEUE_TO_QUEUE format a9 head "Queue to| Queue"
col RULE_SET_NAME format a18
$BREAK
set linesize 125
prompt
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then
   help; exit
fi

# ............ some default values and settings: .................
typeset -u fdest_q
typeset -u fsrc_q
typeset -u fdblink
typeset -u fqueue
typeset -u fowner
typeset -u fprop
EXECUTE=NO

while [ -n "$1" ]
do
  case "$1" in
     -adm ) STREADMIN=$2; shift ;;
   -check ) CHOICE=CHECK ;;
  -create ) TTITLE="Create propagation process" ; CHOICE=CREATE ;;
    -dblk ) fdblink=$2; shift ;;
       -d ) CHOICE=DELTA; DELTA_SEC=$2 ; shift ;;
   -destq ) fdest_q=$2; shift ;;
    -drop ) TTITLE="Drop propagation process" ; fprop=$2 ; shift; CHOICE=DROP ;;
  -droprs ) CHOICE=DROP_RS ; fprop=$2; shift ;;
       -l ) EXECUTE=YES ; TTITLE="List propagation process" ; CHOICE=LIST_PROP ;;
     -lat ) TTITLE="Set the propagancy latancy (in seconds) " ; latency=$2; shift ; CHOICE=SET_LAT ;;
      -lc ) EXECUTE=YES ; TTITLE="List schedules for propagation process" ; CHOICE=SCHEDULE ;;
      -lq ) EXECUTE=YES ; TTITLE="List propagation Queue to queue correspondancies" ; CHOICE=Q_TO_Q ;;
      -lr ) EXECUTE=YES ; TTITLE="List propagation rules " ; CHOICE=PROP_RUL ;;
       -n ) REPEAT_COUNT=$2 ; shift ;;
       -o ) EXECUTE=YES ; TTITLE="Show propagation overal status and figures" ; CHOICE=OVERVIEW ; REMOTEDB=$2; shift ;;
      -pn ) fprop=$2; shift ;;
      -qn ) fqueue=$2; shift ;;
       -r ) EXECUTE=YES ; TTITLE="Stats for propagation receiver" ; CHOICE=STATS_R ;;
     -rcr ) TTITLE="Re-create propagation process" ; CHOICE=RECREATE ;;
       -s ) EXECUTE=YES ; TTITLE="Stats for propagation sender" ; CHOICE=STATS ;;
    -stop ) TTITLE="Stop propagation process" ; CHOICE=STOP ; fprop=$2 ; shift ;;
   -start ) TTITLE="Start propagation process"; fprop=$2 ; shift; CHOICE=START ;;
 -sourceq ) fsrc_q=$2; shift ;;
   -trace ) TRACE="alter system set events = '24040 trace name context forever, level 10' ;" ;;
       -u ) fowner=$2; shift ;;
      -u2 ) fowner2=$2; shift ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
if [  "$CHOICE" = "CREATE" -o "$CHOICE" = "RECREATE" -o "$CHOICE"  = "SET_LAT" -o "$CHOICE" = "DROP_RS"  \
   -o "$CHOICE"  = "OVERVIEW"  -o "$CHOICE" = "START" -o "$CHOICE" = "CHECK" ] ;then
   if [ -z "$fowner" ];then
      . $SBIN/scripts/passwd.env
      . ${GET_PASSWD} $S_USER $ORACLE_SID
      if [  "x-$CONNECT_STRING" = "x-" ];then
         echo "could no get a the password of $S_USER"
         exit 0
      fi
      echo "No queue owner given, fetching first username from dba_streams_administrator"
      var=`sqlplus -s "$CONNECT_STRING"<<EOF
      set head off pagesize 0 feed off verify off
      select username from dba_streams_administrator where rownum = 1;
EOF`
      STRMADMIN=`echo $var | tr -d '\n' | awk '{print $1}'`
      S_USER=$STRMADMIN
      fowner=${STRMADMIN:-STRMADMIN}
   else
      S_USER=$fowner
   fi
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
   if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      echo "Trying to complete request defaulting password to match username $STRMADMIN"
      Q_PASSWD=${Q_PASSWD:-$STRMADMIN}
      CONNECT_STRING="$fowner/$Q_PASSWD"
   fi
else
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} SYS $ORACLE_SID
fi
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

var=`$SBINS/smenu_get_ora_version.sh`
vers=`echo $var | grep -v could`
# ...................................................................................
if [ "$CHOICE" = "DROP_RS" ];then
   fowner=${fowner:-$STRMADMIN}
   SQL="prompt Doing execute dbms_propagation_adm.alter_propagation(propagation_name=> '$fprop',remove_rule_set=> TRUE);;
execute dbms_propagation_adm.alter_propagation(propagation_name=> '$fprop',remove_rule_set=> TRUE);
"
# ...................................................................................
elif [ "$CHOICE" = "CHECK" ];then
   if [ -n "$fowner2" ];then
       VAR2=$fowner
   else
       VAR2=$STRMADMIN
   fi
SQL=" SET SERVEROUTPUT ON size 9999
prompt return value of 1 means propagation is ok, 0 is NOK
prompt
DECLARE
rc_value number;
BEGIN
DBMS_AQADM.VERIFY_QUEUE_TYPES(src_queue_name => '$STRMADMIN.$fsrc_q',
dest_queue_name => '$VAR2.$fdest_q',
destination => '$fdblink',
rc => rc_value);
dbms_output.put_line('rc_value code is '||rc_value);
END;
/

"
# ...................................................................................
elif [ "$CHOICE" = "OVERVIEW" ];then
   if [ -z "$REMOTEDB" ];then
         echo "I need the name of the remote DB to compre local capture to remote apply"
         echo "I will use STRMADMIN dblink"
         exit
   fi
SQL="set linesize 132
col Stream head 'Stream|Type' justify l
col capture_name for a30
col QUEUE_NAME for a30
col RULE_NAME for a20
col last_snc for 999999999999
break on stream on capture_name on QUEUE_NAME on report
SELECT 'cap' stream, capture_name,  queue_name, rule_type, rule_name , last_enqueued_scn last_snc
       FROM dba_capture dc, dba_streams_rules dsr
      WHERE dsr.rule_set_name = dc.rule_set_name
union
SELECT 'app' stream, dc.apply_name,   queue_name,rule_type, rule_name , nvl(r.DEQUEUED_MESSAGE_NUMBER,0) last_dequeued
       FROM dba_apply@$REMOTEDB dc, dba_streams_rules@$REMOTEDB dsr, V\$STREAMS_APPLY_READER@$REMOTEDB r
      WHERE dsr.rule_set_name = dc.rule_set_name
        and dc.apply_name = r.apply_name (+)
union
SELECT 'prop' stream,propagation_name,  source_queue_name,rule_type, rule_name,0 FROM dba_propagation dc, dba_streams_rules dsr
      WHERE dsr.rule_set_name = dc.rule_set_name
order by stream desc
/
"
# ...................................................................................
elif [ "$CHOICE" = "PROP_RUL" ];then
SQL="set long 4000
select rsr.rule_set_owner||'.'||rsr.rule_set_name rsn ,rsr.rule_owner||'.'||rsr.rule_name rn,
r.rule_condition rt from dba_rule_set_rules rsr, dba_rules r where rsr.rule_name = r.rule_name and rsr.rule_owner = r.rule_owner and rule_set_name in (select
rule_set_name from dba_propagation) order by rsr.rule_set_owner,rsr.rule_set_name;"

# ...................................................................................
elif [ "$CHOICE" = "Q_TO_Q" ];then
SQL="set linesize 132
select PROPAGATION_NAME,SOURCE_QUEUE_NAME, DESTINATION_QUEUE_NAME , RULE_SET_NAME ,
      QUEUE_TO_QUEUE ,STATUS,to_char(ERROR_DATE,'DD-MM-YYYY HH24:MI:SS') Error_date
from SYS.DBA_PROPAGATION;
select ERROR_MESSAGE from SYS.DBA_PROPAGATION ;
"
# ...................................................................................
elif [ "$CHOICE" = "SCHEDULE" ];then
SQL="set linesize 150
col queue_name HEADING 'Source|Queue Name'
col queue_schema HEADING 'Source|Queue Owner'
col dblink format a34 head 'Destination|Database Link'
COLUMN SCHEDULE_STATUS HEADING 'Schedule Status' FORMAT A23
COLUMN PROPAGATION_NAME Heading 'Propagation|Name' format a25 wrap
COLUMN START_DATE HEADING 'Expected |Start Date'
COLUMN PROPAGATION_WINDOW HEADING 'Duration|in Seconds' FORMAT 9999999999999999
COLUMN NEXT_TIME HEADING 'Next|Time' FORMAT A8
COLUMN LATENCY HEADING 'Latency|in Seconds' FORMAT 9999999999
COLUMN SCHEDULE_DISABLED HEADING 'Status' FORMAT A8
COLUMN PROCESS_NAME HEADING 'Schedule|Process|Name' FORMAT A8
COLUMN FAILURES HEADING 'Number of|Failures' FORMAT 99
COLUMN LAST_ERROR_MSG HEADING 'Error Message' FORMAT A55
COLUMN TOTAL_BYTES HEADING 'Total Bytes|Propagated' FORMAT 9999999999999999
COLUMN CURRENT_START_DATE HEADING 'Current|Start' FORMAT A17
COLUMN LAST_RUN_DATE HEADING 'Last|Run' FORMAT A17
COLUMN NEXT_RUN_DATE HEADING 'Next|Run' FORMAT A17
COLUMN LAST_ERROR_DATE HEADING 'Last|Error Date' FORMAT A17
COLUMN LAST_ERROR_TIME HEADING 'Last|Error time' FORMAT A12
column message_delivery_mode HEADING 'Message|Delivery|Mode'
column queue_to_queue HEADING 'Q-2-Q'
col destination format a50
col sid for a4
col tot_k for 999999999999 head 'Total |Sent (Kb)' justify L

prompt
prompt When the duration is NULL, the propagation is active
prompt When the next time is NULL, the propagation job is currently running
prompt

SELECT substr(session_id, 0, instr(session_id,',')-1) sid ,
       p.propagation_name,TO_CHAR(s.START_DATE, 'HH24:MI:SS MM/DD/YY') START_DATE,
       s.PROPAGATION_WINDOW, s.NEXT_TIME, s.LATENCY,
       DECODE(s.SCHEDULE_DISABLED, 'Y', 'Disabled', 'N', 'Enabled') SCHEDULE_DISABLED,
       (select value/1024  from v\$sesstat x, v\$statname y
                where  x.STATISTIC# = y.STATISTIC# and y.name = 'bytes sent via SQL*Net to dblink'
                   and x.sid=substr(session_id, 0, instr(session_id,',')-1) ) tot_k
  FROM
      DBA_QUEUE_SCHEDULES s,
      DBA_PROPAGATION p
  WHERE  p.DESTINATION_DBLINK = NVL(REGEXP_SUBSTR(s.destination, '[^@]+', 1, 2), s.destination)
         AND s.SCHEMA = p.SOURCE_QUEUE_OWNER
         AND s.QNAME = p.SOURCE_QUEUE_NAME
         and s.message_delivery_mode='BUFFERED'  and session_id is not null
  order by  propagation_name ;

select p.propagation_name, s.message_delivery_mode,
       s.FAILURES,
       p.queue_to_queue,
       s.LAST_ERROR_MSG
  FROM
        DBA_QUEUE_SCHEDULES s,
        DBA_PROPAGATION p
  WHERE
         p.DESTINATION_DBLINK = NVL(REGEXP_SUBSTR(s.destination, '[^@]+', 1, 2), s.destination)
     AND s.SCHEMA = p.SOURCE_QUEUE_OWNER
     AND s.QNAME  = p.SOURCE_QUEUE_NAME
  order by propagation_name,s.message_delivery_mode ;

SELECT p.propagation_name,  TO_CHAR(s.LAST_RUN_DATE, 'HH24:MI:SS MM/DD/YY') LAST_RUN_DATE,
   TO_CHAR(s.CURRENT_START_DATE, 'HH24:MI:SS MM/DD/YY') CURRENT_START_DATE,
   TO_CHAR(s.NEXT_RUN_DATE, 'HH24:MI:SS MM/DD/YY') NEXT_RUN_DATE,
   TO_CHAR(s.LAST_ERROR_DATE, 'HH24:MI:SS MM/DD/YY') LAST_ERROR_DATE,
   LAST_ERROR_TIME
  FROM DBA_QUEUE_SCHEDULES s, DBA_PROPAGATION p
    WHERE   p.DESTINATION_DBLINK =
        NVL(REGEXP_SUBSTR(s.destination, '[^@]+', 1, 2), s.destination)
  AND s.SCHEMA = p.SOURCE_QUEUE_OWNER
  AND s.QNAME = p.SOURCE_QUEUE_NAME order by  propagation_name;
"
# ...................................................................................
elif [ "$CHOICE" = "DELTA" ];then
$SETXV
    #
    # Doing a kornshell loop, for can't flush intermediate results with PL/SQL dbms_out.put_line
    #
    REPEAT_COUNT=${REPEAT_COUNT:-1}
    DELTA_SEC=${DELTA_SEC:-1}
    cpt=0;
    while [ $cpt -lt $REPEAT_COUNT ]
    do
      cpt=`expr $cpt + 1`
      sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 190 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 -- This procedure gives the traffic delta for each propagation
 -- declaration type section
 type rec_sess is record ( c_sid       number,
                      c_stat#     number,
                      c_value     number,
                      c_stat_name varchar2(65),
                      c_prop_name varchar2(65) ) ;
 type typ_rec_sess is table of rec_sess INDEX BY BINARY_INTEGER;
 -- type asys is table of number INDEX BY BINARY_INTEGER;     -- global system measurement , used to produce %
 -- variable declaration session

 a          typ_rec_sess;                   -- a contains sessions first  measurement
 b          typ_rec_sess;                   -- b contains sessions second measurement
 -- a_sys      asys;                           -- a_sys contain first system measurement
 -- b_sys      asys;                           -- b_sys contain second system measurement
 a_sys_tot  number:=0;
 b_sys_tot  number:=0;
 tot_dblk   number:=0;
 key        number:=0;
 v_cpt      number:=0;
 v_sid      number ;
 v_stat#    number ;
 v_mul      number ;
 v_old_prop varchar2(60):='to_init';
 v_prop     varchar2(60);
 v_num_loop number:=1;              --  maybe one day we could flush dbms_output then current procedure support also n loops
 v_delta    number:=$DELTA_SEC ;    --  interval beetwen the 2 measurements
 v_div      number:=1024;           --  for report, set to 1048576 for megs or 1 for bytes
 v_perc     varchar2(20);
 -- ..................................................................
 function show_result return number is
 begin

   dbms_output.put_line (chr(10)||'Date : '||to_char(sysdate,'YYYY-MM-DD HH24:MI:SS') || '     Delta secs --> '|| to_char(v_delta)   );
   DBMS_OUTPUT.PUT_LINE ('.                                                                                                                                 %occup' );
   DBMS_OUTPUT.PUT_LINE ('Propagation                    Statistic name                            Start value(kb) End value(kb)   Delta(kb)  Delta Kb/s    dblink');
   DBMS_OUTPUT.PUT_LINE ('------------------------------ ----------------------------------------  --------------- -------------- ---------- -----------  ----------') ;

   if b.count = 0 then
      return 1 ;
   end if;

   v_cpt:=0;
   FOR i in b.FIRST .. b.LAST
   LOOP
       if b.exists(i) then
           if a.exists(i) then
              -- we found a match of keys between A and B
              if a(i).c_prop_name = v_old_prop then
                 v_prop:='.' ;
              else
                 v_prop:=a(i).c_prop_name;
                 if v_old_prop != 'to_init'  then
                     dbms_output.put_line(chr(10) );
                 end if;
                 v_old_prop:=a(i).c_prop_name;
               end if;
               if tot_dblk > 0 then
                  v_perc:=to_char( ((b(i).c_value-a(i).c_value))/tot_dblk *100 ,'990.9') ;
               else
                  v_perc:='0';
               end if;
               dbms_output.put_line(rpad(v_prop,31,' ')                               ||
                                   rpad(a(i).c_stat_name,42,' ')                     ||
                                   rpad(to_char(a(i).c_value/v_div,'99999999990.9'),15,' ')                ||
                                   rpad(to_char((b(i).c_value)/v_div,'99999999990.9'),15,' ')                ||
                                   rpad(to_char((b(i).c_value-a(i).c_value)/v_div,'9999990.9'),12,' ')   ||
                                   rpad(to_char((b(i).c_value-a(i).c_value)/v_delta/v_div,'9999990.9'),13,' ')    ||
                                   lpad(v_perc,9,' ')
                                   );
           else
              DBMS_OUTPUT.PUT_LINE('Nk'||to_char(i) );
           end if;
       end if ;
   END LOOP ;
   return 1 ;
 end; -- end function display result
 -- ..................................................................
begin
    for r in 1..v_num_loop
    loop
    key:=0 ;
    v_cpt:=0 ;
    if a.last is null then
      for s in  ( select distinct to_number( substr(s.session_id, 0, instr(session_id,',')-1) ) sid , p.propagation_name
                      from  DBA_QUEUE_SCHEDULES s,
                            DBA_PROPAGATION p
                      WHERE  p.DESTINATION_DBLINK = NVL(REGEXP_SUBSTR(s.destination, '[^@]+', 1, 2), s.destination)
                         AND s.SCHEMA = p.SOURCE_QUEUE_OWNER
                         AND s.QNAME = p.SOURCE_QUEUE_NAME
                         and s.message_delivery_mode='BUFFERED' and session_id is not null
                order by 1 )
     loop
        v_cpt:=v_cpt+1;

        for c in ( select a.statistic#, value, name from v\$sesstat a, v\$statname b
                     where sid = s.sid and a.statistic#=b.statistic# and b.name like 'bytes%dblink%' order by a.sid, a.statistic# )
        loop
           key:=(v_cpt*10000) + c.statistic# ;    -- for every session we add a multiple of 10.000 to the key so that each stats# becomes unique
           a(key).c_sid:=s.sid;                   -- v_cpt = 1 for first session, 2 for second etc.....
           a(key).c_prop_name:=s.propagation_name;
           a(key).c_stat#:=c.statistic#;
           a(key).c_value:=c.value;
           a(key).c_stat_name:=c.name;
        end loop;
     end loop;
   end if;
   -- take the First system measurement
   for sm in (select STATISTIC#, value from v\$sysstat where name like 'bytes%dblink%')  loop
       -- a_sys(sm.STATISTIC#):=sm.value;
       a_sys_tot:=a_sys_tot+sm.value;
   end loop;

   dbms_lock.sleep(v_delta);

   key:=0;
   v_cpt:=0;
   for s in  ( select distinct to_number( substr(session_id, 0, instr(session_id,',')-1) ) sid , p.propagation_name
                      from  DBA_QUEUE_SCHEDULES s,
                            DBA_PROPAGATION p
                      WHERE  p.DESTINATION_DBLINK = NVL(REGEXP_SUBSTR(s.destination, '[^@]+', 1, 2), s.destination)
                         AND s.SCHEMA = p.SOURCE_QUEUE_OWNER
                         AND s.QNAME = p.SOURCE_QUEUE_NAME
                         and s.message_delivery_mode='BUFFERED' and session_id is not null
                order by 1 )
   loop
     v_cpt:=v_cpt+1;

     for c in ( select a.statistic#, value, name from v\$sesstat a, v\$statname b
                     where sid = s.sid and a.statistic#=b.statistic# and b.name like 'bytes%dblink%'
                           order by a.sid,a.statistic# )
     loop
         key:=(v_cpt*10000) + c.statistic# ;
         b(key).c_sid:=s.sid;
         b(key).c_prop_name:=s.propagation_name;
         b(key).c_stat#:=c.statistic#;
         b(key).c_value:=c.value;
         b(key).c_stat_name:=c.name;
     end loop;
   end loop;
   -- take the Second system measurement
   for sm in (select STATISTIC#, value from v\$sysstat where name like 'bytes%dblink%')  loop
         -- b_sys(sm.STATISTIC#):=sm.value;
         b_sys_tot:=b_sys_tot+sm.value;
   end loop;
   tot_dblk:=b_sys_tot-a_sys_tot;
   -- read result
   v_cpt:=show_result;
   a:=b;   -- old values becomes the new references
 end loop;
end ;
/
EOF
done
echo
exit
# ...................................................................................
elif [ "$CHOICE" = "STATS_R" ];then
SQL=" COLUMN SRC_QUEUE_NAME HEADING 'Source|Queue|Name' FORMAT A20
COLUMN DST_QUEUE_NAME HEADING 'Target|Queue|Name' FORMAT A20
COLUMN SRC_DBNAME HEADING 'Source|Database' FORMAT A15
COLUMN ELAPSED_UNPICKLE_TIME HEADING 'Unpickle|Time' FORMAT 99999999.99
COLUMN ELAPSED_RULE_TIME HEADING 'Rule|Evaluation|Time' FORMAT 99999999.99
COLUMN ELAPSED_ENQUEUE_TIME HEADING 'Enqueue|Time' FORMAT 99999999.99

SELECT SRC_QUEUE_NAME,
       SRC_DBNAME,DST_QUEUE_NAME,
       (ELAPSED_UNPICKLE_TIME / 100) ELAPSED_UNPICKLE_TIME,
       (ELAPSED_RULE_TIME / 100) ELAPSED_RULE_TIME,
       (ELAPSED_ENQUEUE_TIME / 100) ELAPSED_ENQUEUE_TIME, TOTAL_MSGS,HIGH_WATER_MARK
  FROM V\$PROPAGATION_RECEIVER;
"
# ...................................................................................
elif [ "$CHOICE" = "STATS" ];then
   SQL="
prompt
prompt ++ EVENTS AND BYTES PROPAGATED FOR EACH PROPAGATION++
prompt
COLUMN Elapsed_propagation_TIME HEADING 'Elapsed |Propagation Time|(Seconds)' FORMAT 9999999999999999
COLUMN TOTAL_NUMBER HEADING 'Total Events|Propagated' FORMAT 9999999999999999
COLUMN SCHEDULE_STATUS HEADING 'Schedule|Status'
column elapsed_dequeue_time HEADING 'Total Dequeue|Time (Secs)'
column elapsed_propagation_time HEADING 'Total Propagation|Time (Secs)' justify c
column elapsed_pickle_time HEADING 'Total Pickle| Time(Secs)' justify c
column total_time HEADING 'Elapsed|Pickle Time|(Seconds)' justify c
column high_water_mark HEADING 'High|Water|Mark'
column acknowledgement HEADING 'Target |Ack'
prompt pickle : Pickling is the action of building the messages, wrap the LCR before enqueuing
prompt
set linesize 150
SELECT p.propagation_name,q.message_delivery_mode queue_type, DECODE(p.STATUS,
                'DISABLED', 'Disabled', 'ENABLED', 'Enabled') SCHEDULE_STATUS, q.instance,
                q.total_number TOTAL_NUMBER, q.TOTAL_BYTES/1048576 total_bytes,
                q.elapsed_dequeue_time/100 elapsed_dequeue_time, q.elapsed_pickle_time/100 elapsed_pickle_time,
                q.total_time/100 elapsed_propagation_time
  FROM  DBA_PROPAGATION p, dba_queue_schedules q
        WHERE   p.DESTINATION_DBLINK = NVL(REGEXP_SUBSTR(q.destination, '[^@]+', 1, 2), q.destination)
  AND q.SCHEMA = p.SOURCE_QUEUE_OWNER
  AND q.QNAME = p.SOURCE_QUEUE_NAME
  order by q.message_delivery_mode, p.propagation_name;
"
# ...................................................................................
elif [ "$CHOICE" = "SET_LAT" ];then
# ------------------------------------------------------------------------------------
#--       DBMS_AQADM.ALTER_PROPAGATION_SCHEDULE(
#--          queue_name        => '&&ApplSchema._strms_q',
#--          destination       => '@&&RemoteDBTNSName',
#--          latency           => NewParamVal,
#--          destination_queue => '&&ApplSchema._strms_q');
#  EXEC DBMS_AQADM.ALTER_SCHEDULE(queue_name,destination,latency=>1);
case $vers in
  9 )  SQL="execute DBMS_AQADM.ALTER_PROPAGATION_SCHEDULE( queue_name => '$fowner.$fqueue', destination => '$fdblink', latency=>$latency)" ;;
  10) SQL="col DESTINATION_QUEUE_NAME new_value DESTINATION_QUEUE_NAME noprint
col DESTINATION_DBLINK new_value DESTINATION_DBLINK noprint
col source_queue_name new_value source_queue_name noprint

 select SOURCE_QUEUE_NAME, DESTINATION_QUEUE_NAME, DESTINATION_DBLINK from SYS.DBA_PROPAGATION  where propagation_name = upper('$fprop');
 set serveroutput on size 9999
  col cmd new_value cmd noprint
  execute DBMS_AQADM.ALTER_PROPAGATION_SCHEDULE( queue_name => 'STRMADMIN.&source_queue_name',  destination =>'&DESTINATION_DBLINK',  destination_queue=>'&DESTINATION_QUEUE_NAME',  latency=>$latency, duration=>null, next_time=>null) ;"
  ;;
esac

# ...................................................................................
elif [ "$CHOICE" = "STOP" ];then
   #SQL="execute DBMS_AQADM.DISABLE_PROPAGATION_SCHEDULE ( queue_name => '$fowner.$fqueue', destination => '$fdblink');"
   SQL="execute DBMS_PROPAGATION_ADM.stop_propagation('$fprop',force=>true);"


# ...................................................................................
elif [ "$CHOICE" = "START" ];then
  if [ "$vers" -eq 9 ];then
      SQL="$TRACE
execute DBMS_PROPAGATION_ADM.start_PROPAGATION( propagation_name => '$fowner.$fprop');"
  else
      SQL=" execute DBMS_PROPAGATION_ADM.start_propagation('$fprop');"
  fi
elif [ "$CHOICE" = "DROP" ];then
  if [ $vers -eq 9 ];then
      SQL="execute DBMS_PROPAGATION_ADM.DROP_PROPAGATION( propagation_name => '$fowner.$fprop');"
  else
      SQL="execute DBMS_PROPAGATION_ADM.DROP_PROPAGATION( propagation_name => '$fprop');"
  fi
# ...................................................................................
elif [ "$CHOICE" = "RECREATE" ];then
SQL="
col propagation_name new_value propagation_name noprint
col RULE_SET_NAME new_value RULE_SET_NAME noprint
col RULE_SET_OWNER new_value RULE_SET_OWNER noprint
col source_queue_name new_value source_queue_name noprint
col source_queue_owner new_value source_queue_owner noprint
col QUEUE_TO_QUEUE new_value QUEUE_TO_QUEUE noprint
col DESTINATION_QUEUE_NAME new_value DESTINATION_QUEUE_NAME noprint
col DESTINATION_QUEUE_OWNER new_value DESTINATION_QUEUE_OWNER noprint
col DESTINATION_DBLINK new_value DESTINATION_DBLINK noprint
col negative_rule_set_name new_value negative_rule_set_name noprint
select propagation_name , RULE_SET_NAME, source_queue_name,QUEUE_TO_QUEUE, DESTINATION_QUEUE_NAME , RULE_SET_OWNER,SOURCE_QUEUE_OWNER,
    DESTINATION_DBLINK,negative_rule_set_name,DESTINATION_QUEUE_OWNER from SYS.DBA_PROPAGATION;

col neg_rls new_value neg_rls
select decode(NEGATIVE_RULE_SET_OWNER||'.'||NEGATIVE_RULE_SET_NAME ,'.','null', NEGATIVE_RULE_SET_OWNER||'.'||NEGATIVE_RULE_SET_NAME ) neg_rls
       from  SYS.DBA_PROPAGATION where propagation_name = upper('$fprop');
execute DBMS_AQADM.DISABLE_PROPAGATION_SCHEDULE ( queue_name => '&DESTINATION_QUEUE_OWNER..&source_queue_name', destination => '&DESTINATION_DBLINK');
execute DBMS_PROPAGATION_ADM.DROP_PROPAGATION( propagation_name => '$fprop');
execute DBMS_PROPAGATION_ADM.CREATE_PROPAGATION( propagation_name => '$fprop', source_queue => '&SOURCE_QUEUE_OWNER..&&source_queue_name', destination_queue => '&DESTINATION_QUEUE_OWNER..&DESTINATION_QUEUE_NAME', destination_dblink => '&DESTINATION_DBLINK', rule_set_name=>'&RULE_SET_OWNER..&rule_set_name' , negative_rule_set_name=>&neg_rls , queue_to_queue=> true);
"
# ...................................................................................
elif [ "$CHOICE" = "CREATE" ];then
  SQL="execute DBMS_PROPAGATION_ADM.CREATE_PROPAGATION( propagation_name => '$fowner.$fprop', source_queue => '$fowner.$fsrc_q', destination_queue => '$fowner.$fdest_q', destination_dblink => '$fdblink');"
elif [ "$CHOICE" = "LIST_PROP" ];then
  SQL="set lines 190
select PROPAGATION_NAME prop,  RULE_SET_NAME rsname , nvl(DESTINATION_DBLINK,'Local to db') d_dblk,NEGATIVE_RULE_SET_NAME
              from dba_propagation ;
  select SOURCE_QUEUE_OWNER||'.'|| SOURCE_QUEUE_NAME nams , DESTINATION_QUEUE_OWNER||'.'|| DESTINATION_QUEUE_NAME||
          decode( DESTINATION_DBLINK,null,'','@'|| DESTINATION_DBLINK) namd, status , QUEUE_TO_QUEUE
              from dba_propagation ;"
fi

# ...................................................................................
#             Execution takes places here
# ...................................................................................
if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

