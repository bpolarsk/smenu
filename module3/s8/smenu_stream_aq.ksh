#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_stream_aq.ksh
# date    : 12 Decembre 2005
#           03 October 2007 : added primary and secondary instances for queue
#                              added optin -bq  to see buffered queues
#                              added optin -bs and -bf to see buffered Subscribers meta data and stats
#                              added optin -bp to see buffered Publishser  data and stats
#           21 November 2007   Added option  -key to option -readp to show the transaction details
#           06 Mars 2008       Added options -txn to extract/apply/purge all LCR related to a TXN ID

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
function get_q_fowner
{
  var=`sqlplus "$CONNECT_STRING"<<EOF
 set head off pagesize 0 feed off verify off
 select owner from dba_queues where name = upper('$par1' )
        and owner not in ( 'SYS','SYSTEM','WMSYS','IX','SYSMAN');
EOF`
ret=`echo $var | tr -d '\n' | awk '{print $1}'`
echo $ret
}
# -------------------------------------------------------------------------------------
function check_par
{
  PAR=\$$1
  eval A=${PAR}
  if [ -z "$A" ];then
     echo "Parameter '$1' is not set"
     exit
  fi
}
# -------------------------------------------------------------------------------------
function help
{

  cat <<EOF

     aq  -q -u <QUEUE_OWNER> -qn <QUEUE_NAME> -p <QUEUE_OWNER_PASSWD> -create <QUEUE_NAME> -l
         -l -stop -start -lq -v -purge -qn <QUEUE_NAME> -cust <QUEUE_CUSTOMER>
         -read <QUEUE_NAME> [-u <QUEUE_OWNER>] -readp <QUEUE_NAME> [-u <QUEUE_OWNER>] -key <MSGID> [-rn <nn>]
      aq -t <QUEUE_TABLE> [-pi <n> [-si <n>]
      aq -ld -lc -lg -lh -ls -lt -li  <QUEUE_TABLE>
      aq -fdrop <owener.Qtable>

          -l : list queue figures                     -readp : read the AQ\$_<QUEUE_NAME>_P header for each objects
          -q : list all queue                          -key  : display all values from a given transaction row in a transaction
         -bq : list buffered queues                             (the row is identified by its MSGID number)
          -s : list buffered suscribers figures           -v : Verbose : show sql text
          -b : list buffered publisher                   -pi : Primary Instance number for the owner of the queue table
         -sm : list buffered suscribers metadata         -si : Secondary Instance number for the owner of the queue table
         -la : Show acknowlege progresses
     -create : Create a queue                           -siz : List name and size to objects associated to Queue tables
      -start : Start a queue                             -qt : list all queue tables and their real size in blocks
       -stop : Stop a queue                               -p : Queue owner password (default to queue_owner)
       -drop : Drop a queue                               -k : Reduce HWM for queue table and associated _P and IOT
      -purge : Purge a queue                        -fdrop  : Force a drop of a queue table
     -purgep : Remove all rows from axception queue      -rn : Limite select to <nn> first rows
         -lq : list queue contents                       -gm : List size of all AQ\$ tables
         -qn : Queue name                             -sched : Queue schedule
          -t : Queue table                                -u : Queue owner
        -l[c|d|g|h|i|s|t] <QUEUE_NAME> : List AQ\$_<queue_name>_<x> associated IOT queue contents
        -cd <QUEUE_NAME> : coalesce  AQ\$_<queue_table>_d

     Create a queue           : aq -create -qn <queue_name> -u <queue_owner>
     Start a queue            : aq -start  <queue_name> [-u <queue_owner>]
     Stop a queue             : aq -stop   <queue_name> [-u <queue_owner>]
     drop a queue             : aq -drop   <queue_name> [-u <queue_owner>]
     Purge a queue            : aq -purge  -qn <queue_table>
     change inst owner        : aq -t <queue_table>  -pi <n>
     read queue               : aq -read  <queue_table>
     read exception queue     : aq -readp <queue_table>
     transaction details      : aq -readp <queue_tabke> -key <nnn> | -txn <txn id>
                                 (use  aq -readp <queue name> to see the values <nnn> for -key)
     Rerun contents of _P exception queue  : aq -execute  -qn <queue_name> -u <QUEUE_OWNER>
     shrink queue table and associated _P and IOT tables : aq -k <queue_name>  -u <QUEUE_OWNER>
     coalesce the _d iot : aq -cd <qeueu_name>
     force a drop of queue table :  aq -fdrop   -t <owner.queue_table>

    # ......................................................................................................
    Stream administrator admin and his password can be deduced by smenu if you defined one for this instance
    in SM/3.8 ortherwise it will try to default to STRMADMIN/STRMADMIN
    # ......................................................................................................

EOF

exit
}
# -------------------------------------------------------------------------------------
function do_execute
{
if [ -n "$SETXV" ];then
   echo "$SQL"
fi
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,22,' ')  ||'$TTITLE (aq -h for help)' nline
from sys.dual
/
set head on

col sender_name format a24 head 'Send Name'
col memory_usage format 990 head "Streams|Memory|usage(%)" justify l
col PUBLISHER_STATE format a20 head "Publisher state"
col LAST_ENQUEUED_MSG head "last Enq|Msg"  justify c
col UNBROWSED_MSGS head "Unbrowsed|Msg"  justify c
col OVERSPILLED_MSGS head "Overspil|Msg"  justify c
col SUBSCRIBER_ADDRESS format a50
col SUBSCRIBER_TYPE format a10 head "Subscriber| Type" justify c
col SUBSCRIBER_Name format a20 head "Subscriber| name" justify c
col SUBSCRIBER_ID format 99999 head 'Subsc|  id'
col queue_name format A22 head 'Queue Name'
col LAST_BROWSED_SEQ head "last|browsed|Sequence"  justify c
col TOTAL_DEQUEUED_MSG head "Total|Dequeued|Msg"  justify c
col TOTAL_SPILLED_MSG head "Total|Spilled|Msg"  justify c
col EXPIRED_MSGS head "Expired|Msg"  justify c
col MESSAGE_LAG head "Message|Lag"  justify c
col LAST_DEQUEUED_SEQ head "last|Dequeued|Seq"  justify c
COLUMN LAST_DEQUEUED_SEQ HEADING 'Last|Dequeued|Sequence' FORMAT 99999999
COLUMN NUM_MSGS HEADING 'Messages|in Queue|(Current)' FORMAT 99999999
COLUMN CNUM_MSGS HEADING 'Total Msgs|(Cumulative)' FORMAT 99999999
COLUMN TOTAL_SPILLED_MSG HEADING 'Spilled|Messages|(Cumulative)'
col CURRENT_ENQ_SEQ head "Current|Enq Seq"  justify c
col Queue_ID format 99999 head 'Queue|  id'
col wa format 9999999 head 'Msg|Waiting'
col qid format 99999 head 'Qid'
col recipients format A9 head 'Recipient'
col nam format A40 head 'Queue Owner and Name'
col namd format A33 head 'Remote queue'
col nams format A33 head 'Source queue'
col dblk format A12 head 'Dblink'
col queue_table format A24 head 'Queue Table'
col rname format A20 head 'Rule name'
col prop format A22 head 'Propagation name '
col tw format 99999999 head 'Total|wait'
col aw format 999999 head 'Avg.|Wait'
col total_number format 999999999 head 'Number of |Messages|propagated' justify c
col avg_size format 99990.9 head 'Avg|Size'
col avg_time format 990.9999 head 'Avg time|propagat'
col enq format A3 head 'Enq'
col deq format A3 head 'Deq'
col expired format 9999999 head 'Msg|Ready'
col destination format A12 head 'Destination'
col qt format A9 head 'Queue| Type'
col sd format A12 head 'Queue Start'
col scd format A8 head 'Disable'
col lrd format A14 head 'Last run'
col nrd format A14 head 'Next run'
col msg head "Message Count|in Queue"  justify c
$BREAK
set linesize 125

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
typeset -u fqueue
typeset -u fowner
typeset -u fcust
EXECUTE=NO
DO_EXEC=FALSE

while [ -n "$1" ]
do
  case "$1" in
     -err ) CHOICE=ERROR ; TTITLE="Show error for apply process"; EXECUTE=YES ;;
       -l ) EXECUTE=YES ; TTITLE="List Queues in system " ; CHOICE=LIST ;;
      -lq ) CHOICE=Q_CONTENTS; EXECUTE=YES;;
      -la ) CHOICE=ACK; EXECUTE=YES;;
      -cd ) CHOICE=COALESCE_D; QUEUE_TABLE=$2; shift ;EXECUTE=YES;;
      -pi ) EXECUTE=NO ; TTITLE="change queue ownership " ; P_INST_NUM=$2; shift ; CHOICE=OWNERSHIP ;;
      -si ) EXECUTE=NO ; TTITLE="change queue ownership " ; S_INST_NUM=$2; shift ; CHOICE=OWNERSHIP ;;
      -bq ) CHOICE=BUFFERED_Q; EXECUTE=YES;;
       -k ) CHOICE=SHRINK_Q; QTABLE=$2; shift; EXECUTE=YES;;
      -qt ) CHOICE=QTABLE; EXECUTE=YES;;
      -t )  Q_TABLE=$2; shift;;
      -gm ) CHOICE=GM_AQ EXECUTE=YES;;
      -sm ) CHOICE=BUFFERED_S; EXECUTE=YES;;
       -s ) CHOICE=BUFFERED_SF; EXECUTE=YES;;
       -b ) CHOICE=BUFFERED_P; EXECUTE=YES;;
  -create ) CHOICE=CREATE ; TTITEL="Create AQ" ;;
    -drop ) CHOICE=DROP ; Q_NAME=$2; shift ; TTITEL="Drop a Queue" ;;
   -fdrop ) CHOICE=FDROP ; TTITEL="Forec drop of a Queue TABLE" ;;
    -stop ) CHOICE=STOP; Q_NAME=$2 ; shift  ;;
   -purge ) CHOICE=PURGE ;;
  -purgep ) CHOICE=PURGEP; TARGET_QUEUE=$2;shift ;;
   -start ) CHOICE=START ; Q_NAME=$2 ; shift  ;;
   -sched ) CHOICE=SCHEDULE; EXECUTE=YES ;;
       -p ) Q_PASSWD=$2      ; shift;;
       -q ) CHOICE=LIST_Q ; EXECUTE=YES ; TTITLE="List Queues in links" ;;
      -qn ) Q_NAME=$2; shift ;;
       -u ) fowner=$2 ;     shift
            AND_OWNER=" and owner = upper('$fowner')" ;;
     -rn  ) ROWNUM=$2 ;shift ;;
     -lc  ) QUEUE_EXT=C; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -ld  ) QUEUE_EXT=D; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -lg  ) QUEUE_EXT=G; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -lh  ) QUEUE_EXT=H; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -li  ) QUEUE_EXT=I; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -ls  ) QUEUE_EXT=S; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
     -lt  ) QUEUE_EXT=T; QUEUE_TABLE=$2; shift ;CHOICE=LIST_IOTQ;;
    -cust ) fcust=$2     ; shift;;
     -col ) fcol=$2     ; shift;;
    -exec ) DO_EXEC=TRUE ;;
    -read ) CHOICE=READ_QUEUE ; EXECUTE=YES ;  TTITLE="Read queue table"
            TARGET_QUEUE="${2}" ;
            ORIG_TARGET_QUEUE="${2}" ;
            shift ;;
   -readp ) CHOICE=READ_QUEUE ; EXECUTE=YES ; TTITLE="Read exception queue"
            TARGET_QUEUE="${2}_P" ;
            ORIG_TARGET_QUEUE="${2}" ;
            shift ;;
    -txn  ) TXN_ID=$2; shift ;;
    -key  ) MSGID=$2; shift ;;
    -siz  ) CHOICE=SIZ;TTITLE="List name and size to objects associated to Queue tables";EXECUTE=YES;;
 -execute ) CHOICE=READ_QUEUE ; Q_EXEC=TRUE ; EXECUTE=YES ; Q_NAME=$2 ; shift ; TTITlE="Rerun whole exception queue" ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
if [ "$CHOICE" = "CREATE" -o "$CHOICE" = "DROP" -o $CHOICE = "STOP" -o "$CHOICE" = "START" -o "$CHOICE" = "PURGE" -o "$CHOICE" = "READ_QUEUE" -o "$CHOICE"  = "SHRINK_Q" -o "$CHOICE" = "OWNERSHIP"  -o "$CHOICE" = "COALESCE_D"  -o "$CHOICE" = "PURGEP" ];then
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
vers=`$SBINS/smenu_get_ora_version.sh`
if [ "$vers" = "9" ];then
     SERVEROUTPUT_SIZE=99999
else
     SERVEROUTPUT_SIZE=unlimited
fi

#$SETXV

# ........................
#  Show acknowleges
# ........................

if [ "$CHOICE" = "ACK" ];then
SQL="col agent for a60
col CORRELATIONID for a30
set lines 190
select * from sys.aq\$_replay_info ;
"
# ........................
#  Coalesce Associated IOT _D
# ........................

elif [ "$CHOICE" = "COALESCE_D" ];then
TTITLE="COALECE content of $fowner.AQ\$_${QUEUE_TABLE}_D;  "
   EXECUTE=YES ;
   SQL="col address format a30
  alter table $fowner.AQ\$_${QUEUE_TABLE}_D coalesce ;"

# ........................
#  LIST Associated IOT
# ........................

elif [ "$CHOICE" = "LIST_IOTQ" ];then
   TTITLE="List content of $fowner.AQ\$_${QUEUE_TABLE}_$QUEUE_EXT  "
   EXECUTE=YES ;
   ROWNUM=${ROWNUM:-30}
   SQL="col address format a30
col rule_name format a12
col trans_name format a20
col NEGATIVE_RULESET_NAME format a16 head 'Neg rule set'
col RULESET_NAME format a16
col name format a16
col protocol format 9999 head 'prot|ocol'
col SUBSCRIBER_TYPE format 9999 head 'subsc|Type'
set lines 150
  select * from (select * from $fowner.AQ\$_${QUEUE_TABLE}_$QUEUE_EXT) where rownum <=$ROWNUM ;"
# ........................
#  GM_AQ
# ........................

elif [ "$CHOICE" = "GM_AQ" ];then
SQL="
set serveroutput on 
declare

var number:=0 ;
begin

for t in (select owner, table_name from dba_tables where table_name like 'AQ\$%' order by owner,table_name)
loop
   execute immediate('select count(*) from '||t.owner||'.' || t.table_name) into var ;
   dbms_output.put_line(t.owner||'.'||t.table_name ||':' || to_char(var));
end loop ;
end ;
/
"

# ........................
#  siz
# ........................

elif [ "$CHOICE" = "SIZ" ];then
SQL="break on parent_table
col type format a30
col owner format a16
col index_name head 'Related object'
col parent_table format a30
prompt
prompt To shrink a lob associated to a queue type : alter table AQ\$_<queue_table>_P modify lob(USER_DATA) ( shrink space  ) ;
prompt


select a.owner,a.table_name parent_table,index_name ,
       decode(index_type,'LOB','LOB INDEX',index_type) type,
      (select blocks from dba_segments where segment_name=index_name and owner=b.owner) blocks
   from
      dba_indexes  a,
      ( select owner, queue_table table_name from dba_queue_tables
           where recipients='SINGLE' and owner NOT IN ('SYSTEM') and (compatible LIKE '8.%' or compatible LIKE '10.%')
         union
         select owner, queue_table table_name from dba_queue_tables
                where recipients='MULTIPLE' and (compatible LIKE '8.1%' or compatible LIKE '10.%')
     ) b
   where   a.owner=b.owner
       and a.table_name = b.table_name
       and a.owner not like 'SYS%' and a.owner not like 'WMSYS%'
union
-- LOB Segment  for QT
select a.owner,a.segment_name parent_table,l.segment_name index_name, 'LOB SEG('||l.column_name||')' type,
                  (select sum(blocks) from dba_segments where segment_name = l.segment_name ) blob_blocks
             from dba_segments  a,
                  dba_lobs l,
                  ( select owner, queue_table table_name from dba_queue_tables
                           where recipients='SINGLE' and owner NOT IN ('SYSTEM') and (compatible LIKE '8.%' or compatible LIKE '10.%')
                    union
                    select owner, queue_table table_name from dba_queue_tables
                            where recipients='MULTIPLE' and (compatible LIKE '8.1%' or compatible LIKE '10.%')
                  ) b
             where a.owner=b.owner and
                   a.SEGMENT_name = b.table_name  and
                   l.table_name = a.segment_name and
                   a.owner not like 'SYS%' and a.owner not like 'WMSYS%'
union
-- LOB Segment of QT.._P
select a.owner,a.segment_name parent_table,l.segment_name index_name, 'LOB SEG('||l.column_name||')',
       (select sum(blocks) from dba_segments where segment_name = l.segment_name ) blob_blocks
   from dba_segments  a,
          dba_lobs l,
          ( select owner, queue_table table_name from dba_queue_tables
                   where recipients='SINGLE' and owner NOT IN ('SYSTEM') and (compatible LIKE '8.%' or compatible LIKE '10.%')
            union
            select owner, queue_table table_name from dba_queue_tables
                    where recipients='MULTIPLE' and (compatible LIKE '8.1%' or compatible LIKE '10.%')
          ) b
   where a.owner=b.owner and
           a.SEGMENT_name = 'AQ\$_'||b.table_name||'_P'  and
           l.table_name = a.segment_name and
           a.owner not like 'SYS%' and a.owner not like 'WMSYS%'
union
-- Related QT
select a2.owner, a2.table_name parent_table,  '-' index_name , decode(nvl(a2.initial_extent,-1), -1, 'IOT TABLE','NORMAL') type,
          case
               when decode(nvl(a2.initial_extent,-1), -1, 'IOT TABLE','NORMAL') = 'IOT TABLE'
                    then ( select sum(leaf_blocks) from dba_indexes where table_name=a2.table_name and owner=a2.owner)
               when decode(nvl(a2.initial_extent,-1), -1, 'IOT TABLE','NORMAL') = 'NORMAL'
                    then (select blocks from dba_segments where segment_name=a2.table_name and owner=a2.owner)
           end blocks
   from dba_tables a2,
       ( select owner, queue_table table_name from dba_queue_tables
                 where recipients='SINGLE' and owner NOT IN ('SYSTEM') and (compatible LIKE '8.%' or compatible LIKE '10.%')
          union all
          select owner, queue_table table_name from dba_queue_tables
                 where recipients='MULTIPLE' and (compatible LIKE '8.1%' or compatible LIKE '10.%' )
       ) b2
   where
         a2.table_name in ( 'AQ\$_'||b2.table_name ||'_T' , 'AQ\$_'||b2.table_name ||'_S', 'AQ\$_'||b2.table_name ||'_H' , 'AQ\$_'||b2.table_name ||'_G' ,
                            'AQ\$_'|| b2.table_name ||'_I'  , 'AQ\$_'||b2.table_name ||'_C', 'AQ\$_'||b2.table_name ||'_D', 'AQ\$_'||b2.table_name ||'_P')
         and a2.owner not like 'SYS%' and a2.owner not like 'WMSYS%'
union
-- IOT Table normal
select
         u.name owner , o.name parent_table, c.table_name index_name, 'RELATED IOT' type,
         (select blocks from dba_segments where segment_name=c.table_name and owner=c.owner) blocks
   from sys.obj\$ o,
        user\$ u,
        (select table_name, to_number(substr(table_name,14)) as object_id  , owner
                from dba_tables where table_name like 'SYS_IOT_OVER_%'  and owner not like '%SYS') c
  where
          o.obj#=c.object_id
      and o.owner#=u.user#
      and obj# in (
           select to_number(substr(table_name,14)) as object_id from dba_tables where table_name like 'SYS_IOT_OVER_%'  and owner not like '%SYS')
order by parent_table , index_name desc;
"
# ........................
#  change queue ownership
# ........................

elif [ "$CHOICE" = "OWNERSHIP" ];then
   if [ -n "$P_INST_NUM" ];then
       PRIMARY_INSTANCE=", primary_instance=> $P_INST_NUM"
   fi
   if [ -n "$S_INST_NUM" ];then
       SECONDARY_INSTANCE=", secondary_instance=> $S_INST_NUM"
   fi
SQL="prompt doing 'exec DBMS_AQADM.ALTER_QUEUE_TABLE ( queue_table=>'$fowner.$Q_TABLE' $PRIMARY_INSTANCE $SECONDARY_INSTANCE );
exec DBMS_AQADM.ALTER_QUEUE_TABLE ( queue_table=>'$fowner.$Q_TABLE' $PRIMARY_INSTANCE $SECONDARY_INSTANCE );
"
# ........................
# Purge all rows from an exception queue
# ........................

elif [ "$CHOICE" = "SHRINK_Q" ];then
SQL="
set head off  lines 124
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_I shrink space;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_T shrink space;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_H shrink space;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_D shrink space;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_P enable row movement;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_P shrink space cascade;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.AQ\$_${QTABLE}_P disable row movement;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.${QTABLE} enable row movement;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.${QTABLE} shrink space cascade;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');
select 'alter table ' ||OWNER||'.${QTABLE} disable row movement;' from dba_queue_tables where QUEUE_TABLE = upper('$QTABLE');


"
# ........................
# Purge all rows from an exception queue
# ........................

elif [ "$CHOICE" = "QTABLE" ];then
SQL="
select
      QUEUE_TABLE, RECIPIENTS, PRIMARY_INSTANCE , SECONDARY_INSTANCE, OWNER_INSTANCE ,
     ( select sum(blocks) from dba_extents where segment_name = QUEUE_TABLE) blocks
   from dba_queue_tables;"

# ........................
# Purge all rows from an exception queue
# ........................

elif [ "$CHOICE" = "PURGEP" ];then
   VAR=`sqlplus -s "$CONNECT_STRING"<<EOF
set head off pause off verify off feed off
select table_name from dba_tables where table_name like '%${TARGET_QUEUE}_P' $AND_OWNER;
EOF`
TARGET_QUEUE=`echo $VAR|awk '{print $1'}`
if   $SBINS/yesno.sh "to delete from $TARGET_QUEUE"
  then
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER , '$TTITLE (aq -h for help)' from sys.dual
/
set head on linesize 190 feed on verify on
delete from $TARGET_QUEUE ;
EOF
fi
exit
# ........................
# Display the text for a given txn
# ........................
elif [ "$CHOICE" = "READ_QUEUE" -a -n "$MSGID" -o -n "$TXN_ID" ];then
   if [ -n "$ROWNUM" ];then
        AND_ROWNUM=" and rownum < $ROWNUM "
   fi
   if [ -n "$MSGID" ];then
      AND_MSGID="and MSGID = '$MSGID'"
   fi
   if [ -n "$TXN_ID" ];then
      AND_TXNID="and MSGID = '$MSGID'"
      USE_TXNID=TRUE
   else
      USE_TXNID=FALSE
   fi

   VAR=`sqlplus -s "$CONNECT_STRING"<<EOF
set head off pause off verify off feed off
select table_name from dba_tables where table_name like '%$TARGET_QUEUE' $AND_OWNER;
EOF`
TARGET_QUEUE=`echo $VAR|awk '{print $1'}`

sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER , '$TTITLE (aq -h for help)' from sys.dual
/
set head on linesize 190 feed off verify off
set serveroutput on size $SERVEROUTPUT_SIZE
declare
   l_varchar2    varchar2(4000);
   lcr           SYS.LCR\$_ROW_RECORD;
   rc            PLS_INTEGER;
   command       VARCHAR2(20);
   cmdtype       varchar2(64);
   colLen        NUMBER(3) :=30;
   valLen        NUMBER(3):= 45;
   oldColList    SYS.LCR\$_ROW_LIST;
   newColList    SYS.LCR\$_ROW_LIST;
   OldCols       VARCHAR2(2000):='';
   NewCols       VARCHAR2(2000):='';
   strOut        VARCHAR2(2000);
   str           VARCHAR2(2000);
   ddl_lcr       SYS.LCR\$_DDL_RECORD;
   proc_lcr SYS.LCR\$_PROCEDURE_RECORD;
   DDLTxt        CLOB;
   header_to_display boolean:=TRUE;

   --***********************************************************************
  FUNCTION retStr(InData sys.anydata) RETURN VARCHAR2 IS
     ColType   VARCHAR2(20);
     RetVal    VARCHAR2(2000);
  BEGIN
     IF InData IS NULL THEN
        RetVal:= 'ERR! EMPTY ';
     ELSE
     ColType:=InData.GETTYPENAME();
     IF ColType='SYS.NUMBER' THEN
       RetVal:=InData.AccessNumber;
     ELSIF ColType='SYS.CHAR' THEN
       RetVal:=InData.AccessChar;
     ELSIF ColType='SYS.NCHAR' THEN
       RetVal:=InData.AccessNchar;
     ELSIF ColType='SYS.VARCHAR' THEN
       RetVal:=InData.AccessVarchar;
     ELSIF ColType='SYS.VARCHAR2' THEN
       RetVal:=InData.AccessVarchar2;
     ELSIF ColType='SYS.NVARCHAR2' THEN
       RetVal:=InData.AccessNVarchar2;
     ELSIF ColType='SYS.DATE' THEN
       RetVal:=InData.AccessDate;
     ELSIF ColType='SYS.TIMESTAMP' THEN
       RetVal:=InData.AccessTimestamp;
     ELSIF ColType='SYS.TIMESTAMP WITH TIME ZONE' THEN
       RetVal:=InData.AccessTimestampTZ;
     ELSIF ColType='SYS.TIMESTAMP WITH LOCAL TIME ZONE' THEN
       RetVal:=InData.AccessTimestampLTZ;
     ELSIF ColType='SYS.INTERVAL DAY TO SECOND' THEN
       RetVal:=InData.AccessIntervalDS;
     ELSIF ColType='SYS.INTERVAL YEAR TO MONTH' THEN
       RetVal:=InData.AccessIntervalYM;
     ELSE
           RetVal:='-'||ColType||'-';
        END IF;
     END IF;
     return RetVal;
  END retStr;
  --***********************************************************************

begin
     dbms_output.put_line('================================================================================');
     begin
     for p in (select USER_DATA,msgid from $TARGET_QUEUE where 1=1 $AND_MSGID $AND_ROWNUM )
     LOOP
       cmdtype:=p.USER_DATA.GETTYPENAME();

       IF cmdtype = 'SYS.LCR\$_ROW_RECORD' THEN
           rc := p.user_data.GETOBJECT(lcr);
           if ( $USE_TXNID ) then
               if ( lcr.get_transaction_id != '$TXN_ID' )  then
                   GOTO end_loop;
               end if;
           end if;

           if ( header_to_display ) then
                header_to_display:=FALSE;
                dbms_output.put_line('-- Object            :  '|| lcr.get_object_owner||'.'||lcr.get_object_name);
                dbms_output.put_line('-- Command           :  '|| Ltrim(lcr.get_command_type));
                dbms_output.put_line('-- lcr creation time :  '|| to_char(lcr.get_source_time,'YYYY-MM-DD HH24:MI:SS'));
                dbms_output.put_line('-- Txn-ID / SCN      :  '||lcr.get_transaction_id ||' / '||lcr.get_scn||chr(10));
           end if;
           if ( $USE_TXNID ) then
                 dbms_output.put_line(chr(10)||'MSGID -->    ' ||p.msgid);
           end if ;
           oldColList:= lcr.get_values('OLD');
           newColList:= lcr.get_values('NEW','Y');
           strOut:= RPAD(' Column',colLen)||RPAD(' Old Value',valLen) ||RPAD(' New Value',valLen);
           dbms_output.put_line('   ');
           strOut:= RPAD('-',colLen,'-')||RPAD(' -',valLen,'-') ||RPAD(' -',valLen,'-');
           dbms_output.put_line(strOut);

           -- this old trick is derived from the old pick-a-month-pos-in-list-of-all-months-in-year

          FOR i IN 1..oldColList.Count LOOP
             OldCols:= OldCols||oldColList(i).column_name||',';
          END LOOP;

          FOR i IN 1..newColList.Count LOOP
              NewCols:= NewCols||newColList(i).column_name||',';
          END LOOP;

          -- Now, with the function INSTR, we check that the proposed column exists at least in one of the 2 lists

          FOR Col IN (SELECT column_name Name FROM all_tab_columns
              WHERE owner = lcr.get_object_owner
                    AND table_name = lcr.get_object_name
                    AND (INSTR(OldCols,column_name||',') > 0 OR INSTR(NewCols,column_name||',') > 0)
              ORDER BY column_id)
         LOOP
             strOut:= RPAD(Col.Name,colLen)||' ';
             str:= '-';
             IF INSTR(OldCols, Col.Name||',') > 0 THEN
                str:= '"'||retStr(lcr.Get_Value('OLD',Col.Name))||'"';
                IF str IS NULL OR str = '""' THEN
                   str:='NULL';
                ELSIF INSTR(str,'ERR!') > 0 THEN
                   str:='-';
                END IF;
             END IF;
             str:= RPAD(str,valLen); strOut:= strOut||str;
             str:= '-';
             IF INSTR(NewCols, Col.Name||',') > 0 THEN
                str:= '"'||retStr(lcr.Get_Value('NEW',Col.Name,'N'))||'"';
                IF str IS NULL OR str = '""' THEN
                   str:='NULL';
                ELSIF INSTR(str,'ERR!') > 0 THEN
                   str:='-';
                END IF;
             END IF;
             str:= RPAD(str,valLen); strOut:= strOut||str;
             dbms_output.put_line(strOut);
          END LOOP;
      -- DDL
      ELSIF cmdtype = 'SYS.LCR\$_DDL_RECORD' THEN

            rc := p.user_data.GetObject(ddl_lcr);
            dbms_output.put_line('-- Object             : '|| ddl_lcr.get_object_owner||'.'||ddl_lcr.get_object_name);
            dbms_output.put_line('-- Lcr creation Time  : '|| to_char(ddl_lcr.get_source_time,'YYYY-MM-DD HH24:MI:SS'));
            dbms_output.put_line('-- Txn-ID / SCN       : '|| ddl_lcr.get_transaction_id ||' / '||ddl_lcr.get_scn);
            dbms_output.put_line('-- Ddl statement      :');
            DBMS_LOB.CREATETEMPORARY(DDLTxt, TRUE);
            ddl_lcr.get_ddl_text(DDLTxt);
            dbms_output.put_line(DDLTxt);
            DBMS_LOB.FREETEMPORARY(DDLTxt);
      -- PROCEDURE
      ELSIF cmdtype = 'SYS.LCR\$_PROCEDURE_RECORD' THEN
            dbms_output.put_line('PROCED=' ||cmdtype);
            rc := p.user_data.GetObject(proc_lcr);
            dbms_output.put_line('-- Package            : '|| proc_lcr.get_package_owner||'.'||proc_lcr.get_package_name||'.'||proc_lcr.get_procedure_name);
  -- buggy          dbms_output.put_line('-- Publication        : '|| proc_lcr.GET_PUBLICATION);
            dbms_output.put_line('-- Txn-ID / SCN       : '||proc_lcr.get_transaction_id ||' / '||proc_lcr.get_scn);
      END IF;
      if ( '$DO_EXEC' = 'TRUE' ) then
         begin
            lcr.execute(TRUE);
            dbms_output.put_line(chr(10) ||'  LCR Re-Executed  status : OK');
            dbms_output.put_line('delete from $TARGET_QUEUE where MSGID = '''||p.msgid||'''');
            execute immediate ('delete from $TARGET_QUEUE where MSGID = '''||p.msgid||'''');
         exception when others then
           dbms_output.put_line(chr(10) || 'Bleh.. Execute is not NOK');
         end ;
       end if ;
    <<end_loop>>
    null;
    END LOOP;
    exception when no_data_found then null ;
    end ;
end;
/
prompt
EOF
exit
# ........................
# Purge a  queue contents
# ........................
elif [ "$CHOICE" = "READ_QUEUE" ];then
   if [ -n "$ROWNUM" ];then
        WHERE_ROWNUM=" where rownum <= $ROWNUM "
        ORDERBY=" order by msgid desc"
   fi
   if [ -n "$fcol" ];then
      COL_DEF="col varchar2(35);"
      COL_GET_VALUE="col:=lcr.get_value('old','$fcol');"
      #COL_GET_VALUE="col:=to_char(lcr.get_value('old','$fcol'));"
      COL_OUTPUT="||' '||col"
   fi
   if [ "$Q_EXEC" = "TRUE" ];then
       DO_EXEC="lcr.execute(TRUE);"
   else
       unset DO_EXEC
   fi
   VAR=`sqlplus -s "$CONNECT_STRING"<<EOF
set head off pause off verify off feed off
select table_name from dba_tables where table_name like '%$TARGET_QUEUE' $AND_OWNER;
EOF
`
   TARGET_QUEUE=`echo $VAR|awk '{print $1'}`
   SQL="set lines 190
set serveroutput on size $SERVEROUTPUT_SIZE
declare
   l_varchar2 varchar2(4000);
   l_rc          number;
   lcr           SYS.LCR\$_ROW_RECORD;
   rc            PLS_INTEGER;
   object_owner  VARCHAR2(30);
   info          VARCHAR2(60);
   object_name   VARCHAR2(40);
   object_scn    number ;
   dmlcommand    VARCHAR2(20);
   trn    VARCHAR2(200);
   cmdtype varchar2(64);
   -- target_queue varchar2(40);
   $COL_DEF
   ddl_lcr             SYS.LCR\$_DDL_RECORD;
   proc_lcr       SYS.LCR\$_PROCEDURE_RECORD;
   DDLTxt        CLOB;
begin

     dbms_output.put_line('Use ''aq -read[p] $ORIG_TARGET_QUEUE -key <MSGID> to see the transaction details'''||chr(10));
     dbms_output.put_line(' Row type                 MSGID(key)                            Owner.table                            SCN      Command      Transaction ID');
     dbms_output.put_line('==========================================================================================================================================');
     for p in (select b.USER_DATA, b.msgid from
                  ( select frowid from ( select  rowid frowid from $TARGET_QUEUE $ORDERBY ) $WHERE_ROWNUM
                  ) a,
                  $TARGET_QUEUE b
               where a.frowid = b.rowid )
     LOOP
       cmdtype:=p.USER_DATA.GETTYPENAME();
       -- DML
       IF cmdtype = 'SYS.LCR\$_ROW_RECORD' THEN
          rc := p.user_data.GETOBJECT(lcr);
          object_owner := lcr.GET_OBJECT_OWNER();
          object_name  := lcr.GET_OBJECT_NAME();
          object_scn   := lcr.GET_SCN();
          dmlcommand   := lcr.GET_COMMAND_TYPE();
          trn          := lcr.GET_TRANSACTION_ID();
          $DO_EXEC
          $COL_GET_VALUE
          l_varchar2   := rpad(cmdtype,25) ||' '||rpad(to_char(p.msgid),35)|| '  '||rpad(object_owner||'.'
                          || object_name,35,' ') || ' ' ||rpad(object_scn,12,' ') ||' '||rpad(dmlcommand,12,' ')
                          ||' ' ||rpad(trn,14,' ')||' ' ||rpad(info,40,' ') $COL_OUTPUT;
       -- DDL
       elsif cmdtype = 'SYS.LCR\$_DDL_RECORD' THEN

            rc := p.user_data.GetObject(ddl_lcr);
            DBMS_LOB.CREATETEMPORARY(DDLTxt, TRUE);
            ddl_lcr.get_ddl_text(DDLTxt);
            l_varchar2 :=rpad(cmdtype,25)||' ' ||rpad(to_char(p.msgid),35)|| '  '||rpad(ddl_lcr.get_object_owner||'.'||ddl_lcr.get_object_name,35,' ')|| ' ' ||rpad(ddl_lcr.get_scn,12,' ') ||' '||rpad(ddl_lcr.get_source_time,12,' ') ||' ' ||rpad(ddl_lcr.get_transaction_id,14,' ')||' ' ||rpad(DDLtxt,40,' ');
            dbms_output.put_line(l_varchar2);
            DBMS_LOB.FREETEMPORARY(DDLTxt);
       -- PROCEDURE
       elsif cmdtype = 'SYS.LCR\$_PROCEDURE_RECORD' THEN

            rc := p.user_data.GetObject(proc_lcr);
            l_varchar2 :=rpad(cmdtype,25)||' '||rpad(to_char(p.msgid),35)||'  '||rpad( proc_lcr.get_package_owner||'.'|| proc_lcr.get_package_name|| '.'||proc_lcr.GET_PROCEDURE_NAME,35,' ')|| ' ' ||rpad( proc_lcr.get_scn,12,' ')  ||rpad( proc_lcr.get_transaction_id,14,' ');
       else
          l_varchar2:='type not processed by smenu' || cmdtype ;
       end if ;
          dbms_output.put_line(l_varchar2);
    END LOOP;
end;
/
"
# ........................
# Purge a  queue contents
# ........................
elif [ "$CHOICE" = "PURGE" ];then
   VAR=`sqlplus -s "$CONNECT_STRING"<<EOF
set head off pause off verify off feed off
select table_name from dba_tables where table_name = '${Q_NAME}' $AND_OWNER;
EOF`
TARGET_QUEUE=`echo $VAR|awk '{print $1'}`
if   $SBINS/yesno.sh "to delete from $TARGET_QUEUE"
  then
     sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER , '$TTITLE (aq -h for help)' from sys.dual
/
set head on linesize 190 feed on verify on
delete from $TARGET_QUEUE ;
EOF
fi
exit

# ........................
# List queue contents
# ........................
elif [ "$CHOICE" = "Q_CONTENTS" ];then
   SQL="set serveroutput on size $SERVEROUTPUT_SIZE
declare
  v_q varchar2(60);
  v_q0 varchar2(60);
  str_cpt_t varchar2(80);
  str_cpt_q varchar2(80);
  str_cpt_9 varchar2(80);
  sqlt varchar2(500);
  q_type varchar2(20);
  cpt_t integer ;
  cpt_q integer ;
  cpt_9 integer ;
  llen integer ;
  lst integer ;
  est integer ;
  var varchar2(80);
begin
  dbms_output.put_line(':    aq -read(p) <queue_table> [-key <MSGID nnn>]  to display contents/detail ');
  dbms_output.put_line(':    aq -purge(p) <queue_table>                     to purge txn '||chr(10));
  dbms_output.put_line('.                                        Rows in     rows in    Spill' );
  dbms_output.put_line('Queues name                              AQ\$<>_P    Queue Table Stat 9 Queue Type  Recipient  Object_type' );
  dbms_output.put_line('--------------------------------------- ---------- ----------- ------- ------------ ----------  -------------------------');

  FOR t IN (select owner,queue_table table_name, OBJECT_TYPE, recipients from dba_queue_tables  where owner not in ('SYS','SYSTEM','WMSYS','IX','SYSMAN') )
  LOOP

    sqlt:='select count(1) cpt_t from '||t.owner||'.'||t.table_name  ;
    execute immediate(sqlt) into cpt_t ;       -- number or rows in spill queue table
    sqlt:='select count(1) cpt_q from '||t.owner||'.'||'AQ\$_'||t.table_name||'_P where state = 9'  ;
    execute immediate(sqlt) into cpt_9 ;       -- number  unbrowsed msg
-- dbms_output.put_line(sqlt);

    sqlt:='select count(1) cpt_q from '||t.owner||'.'||'AQ\$_'||t.table_name||'_P'  ;
    -- dbms_output.put_line(sqlt);
    begin
        execute immediate(sqlt) into cpt_q ;
    exception
          when others then
       cpt_q:=0;
    end;

    sqlt:='select ''APPLY'' act from dba_apply a,dba_queues b where a.queue_name=b.name and a.queue_owner=b.owner and b.queue_table = ''' ||t.table_name ||''' union select ''CAPTURE'' act from dba_capture a, dba_queues b where a.queue_name=b.name and a.queue_owner=b.owner and b.queue_table = '''||t.table_name||'''' ;

    begin
       execute immediate (sqlt) into q_type;
    exception
       when others then
          q_type:='UNDEFINED';
    end ;
    str_cpt_q:=lpad(to_char(cpt_q),12,' ');
    str_cpt_t:=lpad(to_char(cpt_t),12,' ');
    str_cpt_9:=lpad(to_char(cpt_9),7,' ');
    v_q0:=rpad(t.owner||'.'||t.table_name,35,' ');
    dbms_output.put_line(v_q0 || str_cpt_q||'   '||str_cpt_t||' ' || str_cpt_9||'   '||rpad(q_type,10)||' '||rpad(t.recipients,10)||' '||rpad(t.OBJECT_TYPE,30));
  END LOOP;
end;
/
"


# ........................
# Buffered publisher
# ........................
elif [ "$CHOICE" = "BUFFERED_P" ];then
SQL="set linesize 150
COLUMN SENDER_NAME HEADING 'Capture|Process' FORMAT A14
COLUMN QUEUE_NAME HEADING 'Local|Queue Name' FORMAT A15 justify c
COLUMN SENDER_ADDRESS HEADING 'Remote|Sender Queue' FORMAT A27 justify c
COLUMN LAST_ENQUEUED_MSG HEADING 'Last LCR|Enqueued' FORMAT 99999999
COLUMN CNUM_MSGS HEADING 'Number|of LCRs|Enqueued' FORMAT 99999999
col SENDER_PROTOCOL head 'Send|protocol' justify c
select SENDER_PROTOCOL,SENDER_NAME, QUEUE_NAME, nvl(SENDER_ADDRESS,'  -local queue-')SENDER_ADDRESS,
       CNUM_MSGS,LAST_ENQUEUED_MSG,UNBROWSED_MSGS,OVERSPILLED_MSGS,PUBLISHER_STATE,MEMORY_USAGE
from V\$BUFFERED_PUBLISHERS;
"
# ........................
# Buffered susbscriber stats
# ........................
elif [ "$CHOICE" = "BUFFERED_SF" ];then
SQL=" set linesize 150
select QUEUE_NAME,  SUBSCRIBER_NAME, to_char(STARTUP_TIME,'DD-MM HH24:MI:SS') STARTUP_TIME, LAST_BROWSED_SEQ,
       LAST_DEQUEUED_SEQ,NUM_MSGS,CNUM_MSGS,total_dequeued_msg,TOTAL_SPILLED_MSG,EXPIRED_MSGS,MESSAGE_LAG
       from  V\$BUFFERED_SUBSCRIBERS;"
#SELECT subscriber_name, cnum_msgs, total_dequeued_msg, total_spilled_msg FROM V$BUFFERED_SUBSCRIBERS;

# ........................
# Buffered susbscriber metadata
# ........................
elif [ "$CHOICE" = "BUFFERED_S" ];then
SQL=" set linesize 150
select QUEUE_ID,QUEUE_SCHEMA||'.'||QUEUE_NAME nam, SUBSCRIBER_ID,SUBSCRIBER_NAME, SUBSCRIBER_TYPE,  PROTOCOL,
      SUBSCRIBER_ADDRESS from  V\$BUFFERED_SUBSCRIBERS ;"
# ........................
# Buffered queue
# ........................
elif [ "$CHOICE" = "BUFFERED_Q" ];then
   SQL="select QUEUE_SCHEMA||'.'||QUEUE_NAME nam,to_char(STARTUP_TIME,'DD-MM HH24:MI:SS') Start_time, NUM_MSGS,
        SPILL_MSGS,CNUM_MSGS,CSPILL_MSGS,EXPIRED_MSGS  from v_\$buffered_queues ; "
# ........................
# Scheduled queue
# ........................
elif [ "$CHOICE" = "SCHEDULE" ];then
   SQL="col MESSAGE_DELIVERY_MODE head 'Delivery|Mode' justify c
col LAST_ERROR_TIME format a8 head 'Last|Error|Time'
set lines 132
select MESSAGE_DELIVERY_MODE,schema||'.'||qname  nam, latency, LAST_RUN_DATE,LAST_ERROR_TIME,schedule_DISABLED scd, failures
,AVG_SIZE,AVG_TIME  from dba_queue_schedules
/
select s.schema||'.'||s.qname nam, s.destination, to_char(s.start_Date,'DD-MM HH24:MI') sd,
 to_char(s.last_run_date,'DD-MM HH24:MI:SS') lrd, to_char(next_run_date,'dd-mm HH24:MI:SS') nrd,
   s.total_number, s.avg_size, s.avg_time from DBA_QUEUE_SCHEDULES s, DBA_PROPAGATION p
   WHERE p.DESTINATION_DBLINK = s.DESTINATION AND s.SCHEMA = p.SOURCE_QUEUE_OWNER AND s.QNAME = p.SOURCE_QUEUE_NAME; "

# ........................
# start queue
# ........................
elif [ "$CHOICE" = "START" ];then
   if [ -z "$fowner" ];then
      fowner=`get_q_fowner $Q_NAME`
   fi
   SQL="execute dbms_aqadm.start_queue('$fowner.$Q_NAME', TRUE, TRUE); "

# ........................
# Stop queue
# ........................
elif [ "$CHOICE" = "STOP" ];then
   if [ -z "$fowner" ];then
      fowner=`get_q_fowner $Q_NAME`
   fi
   SQL="execute dbms_aqadm.stop_queue('$fowner.$Q_NAME', TRUE, TRUE, FALSE); "

elif [ "$CHOICE" = "LIST_Q" ];then
  SQL="select PROPAGATION_NAME prop, SOURCE_QUEUE_OWNER||'.'|| SOURCE_QUEUE_NAME nams , DESTINATION_QUEUE_OWNER||'.'||
       DESTINATION_QUEUE_NAME namd, DESTINATION_DBLINK dblk, RULE_SET_NAME rname from dba_propagation; "
# ........................
# List queues
# ........................
elif [ "$CHOICE" = "LIST" ];then

   SQL="set termout off
col version new_value version noprint
col queue_table format A26 head 'Queue Table'
col queue_name format A32 head 'Queue Name'
select substr(version,1,instr(version,'.',1)-1) version from v\$instance;

col mysql new_value mysql noprint
col primary_instance format 9999 head 'Prim|inst'
col secondary_instance format 9999 head 'Sec|inst'
col owner_instance format 99 head 'Own|inst'
COLUMN MEM_MSG HEADING 'Messages|in Memory' FORMAT 99999999
COLUMN SPILL_MSGS HEADING 'Messages|Spilled' FORMAT 99999999
COLUMN NUM_MSGS HEADING 'Total Messages|in Buffered Queue' FORMAT 99999999

set linesize 150
select case
  when &version=9 then ' distinct a.QID, a.owner||''.''||a.name nam, a.queue_table,
              decode(a.queue_type,''NORMAL_QUEUE'',''NORMAL'', ''EXCEPTION_QUEUE'',''EXCEPTION'',a.queue_type) qt,
              trim(a.enqueue_enabled) enq, trim(a.dequeue_enabled) deq, x.bufqm_nmsg msg, b.recipients
              from dba_queues a , sys.v_\$bufqm x, dba_queue_tables b
        where
               a.qid = x.bufqm_qid (+) and a.owner not like ''SYS%''
           and a.queue_table = b.queue_table (+)
           and a.name not like ''%_E'' '
   when &version=10 then ' a.owner||''.''|| a.name nam, a.queue_table,
              decode(a.queue_type,''NORMAL_QUEUE'',''NORMAL'', ''EXCEPTION_QUEUE'',''EXCEPTION'',a.queue_type) qt,
              trim(a.enqueue_enabled) enq, trim(a.dequeue_enabled) deq, (NUM_MSGS - SPILL_MSGS) MEM_MSG, spill_msgs, x.num_msgs msg,
              x.INST_ID owner_instance
              from dba_queues a , sys.gv_\$buffered_queues x
        where
               a.qid = x.queue_id (+) and a.owner not in ( ''SYS'',''SYSTEM'',''WMSYS'',''SYSMAN'')  order by a.owner ,qt desc'
   end mysql
from dual
/
set termout on
select &mysql
/
"

# ........................
# Drop queue
# ........................

elif [ "$CHOICE" = "DROP" ];then
  SQL="execute DBMS_AQADM.DROP_QUEUE( queue_name  => '$Q_NAME', AUTO_COMMIT => TRUE);"

# ........................
# Force drop of queue table
# ........................

elif [ "$CHOICE" = "FDROP" ];then
   SQL="ALTER SESSION SET EVENTS '10851 trace name context forever, level 2';
drop table $Q_TABLE CASCADE CONSTRAINTS; "

# ........................
# Create Queue
# ........................
elif [ "$CHOICE" = "CREATE" ];then
  SQL="execute DBMS_STREAMS_ADM.SET_UP_QUEUE( queue_table => '$Q_NAME', queue_name  => '$Q_NAME');"
fi

if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

