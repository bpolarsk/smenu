#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_stream_capture.ksh
# date    : 15 Decembre 2005
#           09 October  2007 Added -lck -lrp options
#           17 October  2007 Added -lr
#           22 November 2007 added -reset, -ckf, -chk, -cpt

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
function help 
{

  cat  <<EOF

    cap -cn <CAPTURE_NAME> -u <OWNER> -l -qn <QUEUE_NAME> -rs <RULE SET>  -strmadmin <STRMADMIN>
    cap -la [ -id <nn>]    
    cap -cn <CAPTURE_NAME>  -cpt -lstb -lr -lrp -prm -par <nn> -trace <127|0> -ret <nn> -ckf -chk <nn> -reset <scn> 
    cap -get_curr_scn | -lx | -rx <tx id> -cn <CAPTURE_NAME>  | -lo
    cap -t <table> [-so <source owner> -to <target_owner> -tt <target_table> -tbs <tablespace>
    cao -d <secs> [ -n <nn> ] [ -cn <capture_name> ] -v

List:
         cap -l                                      : List capture process  
         cap -lrp                                    : List archived registered for purge      
         cap -la                                     : List min mandatory present on disk archive   
         cap -lr                                     : List rule associate with the capture   
         cap -lg                                     : List logminers sessions
         cap -prm                                    : List capture parameters
         cap -lck                                    : List required checkpoint scn for logminer and the restart capture scn       
         cap -cpt                                    : Count rows in system.logmnr_restart_ckpt\$
         cap -s                                      : Show capture streams execution server stats
         cap -min_si                                 : show lowest Prepared scn    
         cap -i                                      : List table prepared for instantiation

Alter capture:
                  cap -chk           : Set Check point frequency for capture process    
                  cap -ret           : change checkpoint retention time
                  cap -reset [<scn>] : Reset the capture scn to <SCN>. last applied SCN used if SCN not given
                  cap -trace         : Set trace on a capture, 127 to trace, 0 to trace off

Create capture:     cap -create -cn <CAPTURE_NAME> -qn <QUEUE_NAME> -u <QUEUE OWNER> -rs <RULE_SET_NAME>

          prepare schema instantiation:  cap -si -so <OWNER>      
          Prepare table instantiation :  cap -ti -so <source_table_owner> -t <TABLE> -u <strmadmin> 

Stop/abort capture:

        cap -start/stop <CAP_NAME> -x                : Start or stop capture process
        cap -abort -so <OWNER> [-t <table>]          : To cancel schema instantiation, add -t to cancel on the table
        cap -drop <CAP_NAME>                         : Drop a capture process        
        cap -rcfg                                    : Remove streams configuration    
                           -so <source TABLE_OWNE> -t <table> 

Misc:
         -u : Owner of the table or capture process                      -t : table name
       -par : Set parallelism of capture process                       -sga : Set SGA_SIZE for logminser session
        -fk : force a stream checkpoint (_CHECKPOINT_FORCE)          -reset : Reset the capture scn to <SCN>. last applied SCN used if SCN not given
       -gm  : Count rows from system.logmnr data dictionary           -pckp : Purge Restart_logmnr_ckpt\$
      -lstb : List archives with build in dict above first_scn       -build : Export the data dictionary to redo (dbms_capturea_adm.build)
       -ses : List logminer sessions and the capture it is attached     -id : Logminer id
      -shrk : Shrink and analyse table system.logmnr_restart_ckpt\$      -v : Verbose
        -lx : List transaction processed by capture process             -rx : Remove transaction from capture (v\$stream_transaction)
        -lo : List Object replication path                             -rms : Remove rule set [neg or pos]
         -d : capture activity Overview                                  -n : repeat <nn> time the action
        -cn : Capture name                                              -qn : Queue name

          -get_curr_scn : show the current scn. to be used to initialize remote apply process
          -strmadmin    : Use the user in argument to perform the operation

   To set parallelism capture  : cap -par <nn> -cn <CAPTURE_NAME>   | To set checkpoint frequency : cap -chk <nn> -cn <CAPTURE_NAME>
   To set trace on  capture    : cap -trace 127 -cn <CAPTURE_NAME>  | off :  cap -trace 0 -cn <CAPTURE_NAME>
   Remove negative rule set    : cap -rms <CAPTURE> neg             | Remove positive rule set    : cap -rms <CAPTURE> pos

   To SGA of logminer          : cap -sga <nn> -cn <CAPTURE_NAME>     # n is expressed in bytes
   List min SCN requiered  for capture : cap -la     or      cap -la -id <n> if mutliple capture process are present

   Retrive current system scn : -get_curr_scn and perform on remote  'app -si <SCN from get_curr_scn>'
   Streams activity (capture->propagation->apply), Delta of 1 sec, repeat 5 time : cap -d 1 -n 5
    
EOF

exit
}
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
echo
echo $NN "MACHINE $HOST - ORACLE_SID : $ORACLE_SID $NC"
sqlplus -s "$CONNECT_STRING" <<EOF
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)  || '$TTITLE (cap -h for help)' 
from sys.dual
/
set head on
col rsn format A28 head "Rule Set name"
col rn format A30 head "Rule name"
col rt format A64 head "Rule text"
COLUMN DICTIONARY_BEGIN HEADING 'Dictionary|Build|Begin' FORMAT A10
COLUMN DICTIONARY_END HEADING 'Dictionary|Build|End' FORMAT A10
col CHECKPOINT_RETENTION_TIME head "Checkpoint|Retention|time" justify c
col LAST_ENQUEUED_SCN for 999999999999 head "Last scn|enqueued" justify c
col las format 999999999999 head "Last remote|confirmed|scn Applied" justify c
col REQUIRED_CHECKPOINT_SCN for 999999999999 head "Checkpoint|Require scn" justify c
col nam format A31 head 'Queue Owner and Name'
col capture_type format A10 head 'Capture |Type'
col RULE_SET_NAME format a15 head "Rule set Name"
col NEGATIVE_RULE_SET_NAME format a15 head "Neg rule set"
col table_name format A30 head 'table Name'
col queue_owner format A20 head 'Queue owner'
col capture_user format A20 head 'Capture user'
col table_owner format A20 head 'table Owner'
col rsname format A34 head 'Rule set name'
col cap format A22 head 'Capture name'
col ti format A22 head 'Date'
col lct format A18 head 'Last|Capture time' justify c
col cmct format A18 head 'Capture|Create time' justify c
col emct format A18 head 'Last enqueued|Message creation|Time' justify c
col ltme format A18 head 'Last message|Enqueue time' justify c
col ect format 999999999 head 'Elapsed|capture|Time' justify c
col eet format 9999999 head 'Elapsed|Enqueue|Time' justify c
col elt format 9999999 head 'Elapsed|LCR|Time' justify c
col tme format 999999999999 head 'Total|Message|Enqueued' justify c
col tmc format 999999999999 head 'Total|Message|Captured' justify c
col status format A8 head 'Status'
col scn format 999999999999 head 'Scn' justify c
col emn format 999999999999 head 'Enqueued|Message|Number' justify c
col cmn format 999999999999 head 'Captured|Message|Number' justify c
col lcs format 999999999999 head 'Last scn|Scanned' justify c
col ncs format 999999999999 head 'Captured|Start scn' justify c
col AVAILABLE_MESSAGE_NUMBER format 999999999999 head 'Last system| scn'  justify c
$BREAK
set linesize 132
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
typeset -u ftable
typeset -u ftarget_table
typeset -u fdblk
typeset -u fcapture
typeset -u fsource_owner
typeset -u ftarget_owner
typeset -u fowner
typeset -u frsname
typeset -u fqueue
STRMADMIN=${STRMADMIN:-STRMADMIN}
EXECUTE=NO
ROWNUM=40
while [ -n "$1" ]
do
  case "$1" in
   -abort ) TTITLE="ABORT instantiation" ; ACTION=ABORT ; CHOICE=ABORT_INSTANTIATE ;;
   -build ) CHOICE=BUILD ;;
     -chk ) TTITLE="Set checkpoint frequency " ; check_freq=$2 ; shift ; CHOICE=CHECK_FREQ ;;
      -cn ) fcapture=$2 ; shift ;;
  -create ) CHOICE=CREATE ;;
     -cpt ) EXECUTE=YES; CHOICE=COUNT; TTITLE="Count rows in system.logmnr_restart_ckpt\$ ";;
      -cs ) cs=$2; shift ;;
       -d ) CHOICE=DO_DELTA; DELTA_SEC="$2" ; shift ;;
    -dblk ) fdblk=$2; shift ;;
    -drop ) CHOICE=START_STOP_DROP ; fcapture=$2 ; shift ; ACTION=DROP;;
     -fk ) TTITLE="Set _CHECKPOINT_FORCE capture " ; PAR=_CHECKPOINT_FORCE ; value="'Y'" ; fcapture=$2;shift ; CHOICE=SET_PAR ;;
  -get_curr_scn  ) CHOICE=GET_CURR_SCN ; EXECUTE=YES;;
      -gm ) CHOICE=GM ; EXECUTE=YES ;;
       -i ) TTITLE="Table Prepared for instantiation" ; EXECUTE=YES ; CHOICE=TBL_INS ;;
      -id ) LOGMNR_ID=$2; shift ;;
       -l ) EXECUTE=YES ; TTITLE="List capture process" ; CHOICE=LIST ;;
      -la ) CHOICE=LOGMINER; TTITLE="List minimum requiered archived log"  ; EXECUTE=YES;;
     -lck ) CHOICE=LIST_LCK; TITTLE="List Checkpoints" ; EXECUTE=YES ;;
      -lr ) CHOICE=CAP_RUL; TTITLE="List capture rule "  ; EXECUTE=YES;;
      -lg ) CHOICE=LIST_LG; TTITLE="List logminers sessions "  ; EXECUTE=YES;;
      -lx ) CHOICE=LIST_TX; TTITLE="List transaction still active in capture"  ; EXECUTE=YES;;
      -lo ) CHOICE=LIST_DIFF ;;
     -lrp ) CHOICE=REGISTERED; TTITLE="List archived log purge status"  ; EXECUTE=YES;;
    -lstb ) CHOICE=LSTB ; EXECUTE=YES ;;
  -min_si ) TTITLE="Show lowest prepared SCN" ; CHOICE=MIN_SI ; EXECUTE=YES ;;
       -n ) REPEAT_COUNT=$2 ; shift ;;
     -par ) TTITLE="Set parallel capture " ; PAR=parallelism ; value=$2 ; shift ; CHOICE=SET_PAR ;;
    -pckp ) CHOICE=PURGE_CKP ;;
     -prm ) CHOICE=PARAMETERS; TITTLE="List Capture parameters"; EXECUTE=YES;;
      -qn ) fqueue=$2 ; shift ;;
     -ret ) TTITLE="Set  checkpoint retention time " ; value=$2 ; shift ; CHOICE=SET_RET ;;
   -reset ) CHOICE=RESET_SCN ; 
            if [ -n "$2" ];then
                 SCN=$2; shift
            fi ;;
      -rs ) frsname=$2 ; shift ;;
     -rms ) CHOICE=REMOVE_RULE_SET ; fcapture=$2 ; RMS_TYPE=$3; shift ; shift ;;
    -rcfg ) CHOICE=RCFG  ;;
      -rn ) ROWNUM=$2;shift;;
      -rx ) CHOICE=REMOVE_TX; TX_ID=$2  ; shift ; TTITLE="Remove transaction still active in capture"  ;; 
       -s ) TTITLE="List execute capture server process stats" ; EXECUTE=YES ; CHOICE=CAPTURE_SERVER ;;
     -sga ) TTITLE="Set SGA_SIZE for logminer " ; sga_size=$2 ; shift ; CHOICE=SET_SGA ;;
     -ses ) TTITLE="List logminer sessions and the capture it is attached" ; CHOICE=LIST_SES ; EXECUTE=YES;;
      -si ) TTITLE="Prepare schema instantiation"; CHOICE=PREPARE ;;
      -so ) fsource_owner=$2 ; shift ;;
    -shrk ) EXECUTE=YES; CHOICE=SHRINK; TTITLE="Shrink and analyse table system.logmnr_restart_ckpt\$";;
 -src_sid ) src_sid=$2 ; shift ;;
   -start ) TITTLE="Starting capture $fcapture"; CHOICE=START_STOP_DROP ; fcapture=$2 ; shift ; ACTION=START ;;
    -stop ) TITTLE="Stopping capture $fcapture";CHOICE=START_STOP_DROP ; fcapture=$2 ; shift ; ACTION=STOP ;;
-strmadmin ) STRMADMIN=$2; S_USER=$STRMADMIN; shift ;;
      -to ) ftarget_owner=$2 ; shift ;;
      -tt ) ftarget_table=$2 ; shift ;;
     -tbs ) ftbs=$2 ; shift ;;
       -t ) ftable=$2; shift ;;
      -ti ) TTITLE="Prepare table instantiation" ; CHOICE=PREPARE ;;
   -trace ) TTITLE="Set trace level " ; trace_level=$2 ; shift ; CHOICE=TRACE ;;
       -u ) fowner=$2 ; shift ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
# retrieve the STRMADMIN user and password
if [  "$CHOICE" = "CREATE" -o "$CHOICE" = "PREPARE"  -o "$CHOICE" = "DO_DELTA"  ];then
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
if [ -z "$cs" ];then
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
else
  CONNECT_STRING=$cs
fi
# ......................................
# Delta
# ......................................
if [ "$CHOICE" = "DO_DELTA" ];then
    #
    # Doing a kornshell loop, for can't flush intermediate results with PL/SQL dbms_out.put_line
    #
    # This routine assumes that dba_streams_administrator are all the same with same password and
    # correspond to  name returned by "select username from dba_streams_administrator where rownum = 1;"
    # the routine connect to this username to perform its task. If it is not the case then you have
    # to restrict and provide the strmadmin username and connection and the routine will only report
    # delta for capture this administrator manage
    #
    if [ -n "$fcapture" ];then
        AND_CAP=" and c.capture_name = '$fcapture'" 
    fi
    echo "CONNECT_STRING=$CONNECT_STRING"
    REPEAT_COUNT=${REPEAT_COUNT:-1}
    DETLA_SEC=${DETLA_SEC:-1}
    cpt=0;
    $SETXV   
    echo "                          scn    msg    cap                              msg                             App    Read    msg    msg   app"
    echo " Capture                  scan   enq   spill   Propagation               prop  Apply                     deq    deq.    app    err  spill" 
    echo " ----------------------- ------ ------ ------ ------------------------- ----- ------------------------ ------ ------ ------ ------ ------  "
   
    while [ $cpt -lt $REPEAT_COUNT ]
    do
      cpt=`expr $cpt + 1`
      sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 512 pagesize 333 feed off head off
set serveroutput on size 999999
declare
 -- This procedure gives the activity delta for complete line capture->propagation->apply
 -- declaration type section
 type rec_sess is record ( id               number,      -- logminer id
                           cap_name         varchar2(30),
                           cap_msg_scanned  number,
                           cap_msg_enqueued number,
                           cap_spill        number,
                           prop_name        varchar2(30),
                           prop_msg         number,
                           app_name         varchar2(30),
                           app_deq          number,
                           reader_rcv       number,
                           coor_app         number,
                           app_err          number,
                           app_spill        number
                          ) ;
 type typ_rec is table of rec_sess INDEX BY BINARY_INTEGER;
 a           typ_rec;                   -- a contains first  measurement
 b           typ_rec;                   -- b contains second measurement
 key         number:=0;
 v_cpt       number:=0;
 sqlcmd      varchar2(1024) ;
 v_msg_deq   number;
 v_msg_app   number;
 v_msg_rcv   number;
 v_msg_err   number;
 v_app_spill number;
 v_app_name  varchar2(30);
 v_delta     number:='$DELTA_SEC' ;

  procedure show_result is 
    v_old_cap  varchar2(30);
    v_cap      varchar2(30);
    v_prop     varchar2(30);
    v_app      varchar2(30);
var number;
  begin
     FOR i in b.FIRST .. b.LAST
     LOOP
       if b.exists(i) then
          if a.exists(i) then
            -- we found a match of keys between A and B
            dbms_output.put_line(rpad(b(i).cap_name,24,' ')                        || ' ' ||
                    rpad(to_char(b(i).cap_msg_scanned -  a(i).cap_msg_scanned ,99990),6,' ')       || ' ' ||
                    rpad(to_char(b(i).cap_msg_enqueued - a(i).cap_msg_enqueued,99990),6,' ')       || ' ' ||
                    rpad(to_char(b(i).cap_spill - a(i).cap_spill,99990),6,' ')     || ' ' ||
                    rpad(b(i).prop_name,24,' ')                                    || ' ' ||
                    rpad(to_char(b(i).prop_msg - a(i).prop_msg,99990),6,' ')       || ' ' ||
                    rpad(b(i).app_name,24,' ')                                     || ' ' ||
                    rpad(to_char(b(i).app_deq - a(i).app_deq,99990),6,' ')         || ' ' ||
                    rpad(to_char(b(i).reader_rcv - a(i).reader_rcv,99990),6,' ')   || ' ' ||
                    rpad(to_char(b(i).coor_app - a(i).coor_app,99990),6,' ')       || ' ' ||
                    rpad(to_char(b(i).app_err - a(i).app_err,99990),6,' ')         || ' ' ||
                    rpad(to_char(b(i).app_spill - a(i).app_spill,99990),6,' ')
               );
          end if;
       end if;
     end loop ;
  end ;

  function take_measurement  return typ_rec is
     row   typ_rec;
  begin
     for c in ( select 
                l.DB_LINK, a.USERNAME stream_admin , 
                p.propagation_name, p.source_queue_name, 
                p.destination_queue_name destination_queue_name,
                c.capture_name, c.logminer_id,
                nvl(sc.total_messages_captured,0) msg_scanned, 
                nvl(sc.total_messages_enqueued,0) msg_enqueued, ps.TOTAL_MSGS msg_prop,
                bq.spill_msgs cap_spill 
             from
                dba_db_links  l,
                dba_streams_administrator a,
                dba_propagation p,
                dba_capture c,
                gv\$streams_capture sc,
                gv\$propagation_sender ps,
                gv\$buffered_queues bq 
             where
                l.username           =  a.username          and
                p.destination_dblink =  l.db_link           and
                p.source_queue_name  =  c.queue_name        and
                p.source_queue_owner =  c.queue_owner       and
                sc.LOGMINER_ID (+)   =  c.logminer_id       and
                sc.capture_name      =  c.capture_name      and
                ps.queue_name        =  c.queue_name        and  
                ps.QUEUE_SCHEMA      =  c.QUEUE_OWNER       and
                bq.queue_name        =  c.queue_name        and  
                bq.QUEUE_SCHEMA      =  c.QUEUE_OWNER $AND_CAP
             )
     loop
        sqlcmd:='select a.apply_name,total_messages_dequeued, total_received,' 
            ||' total_applied, total_errors, bq.spill_msgs '
            ||' from gv\$streams_apply_reader@' ||  c.db_link || ' r, '
            || '     dba_apply@' || c.db_link ||' a,' 
            || '     gv\$streams_apply_coordinator@' || c.db_link ||  ' c, '
            || '     gv\$buffered_queues@' || c.db_link  ||' bq ' 
            ||'  where '
            ||'     r.apply_name (+) = a.apply_name and '
            ||'     a.queue_name     = ''' || c.destination_queue_name|| ''' and '
            ||'     c.apply_name (+) = a.apply_name and ' 
            ||'     bq.queue_name(+) = a.queue_name' ;
         execute immediate sqlcmd into v_app_name, v_msg_deq,v_msg_rcv, v_msg_app, v_msg_err,v_app_spill;
         key                       := c.logminer_id ;
         row(key).id               := c.logminer_id   ;
         row(key).cap_name         := c.capture_name  ;
         row(key).cap_msg_scanned  := c.msg_scanned   ;
         row(key).cap_msg_enqueued := c.msg_enqueued  ;
         row(key).cap_spill        := c.cap_spill  ;
         row(key).prop_name        := c.propagation_name ;
         row(key).prop_msg         := c.msg_prop ;
         row(key).app_name         := v_app_name ;
         row(key).app_deq          := v_msg_deq ;
         row(key).reader_rcv       := v_msg_rcv ;
         row(key).coor_app         := v_msg_app ;
         row(key).app_err          := v_msg_err ;
         row(key).app_spill        := v_app_spill ;
  end loop;
  return row;
  end ;    -- end procedure take measurement

begin
  -- First measurement
  a:=take_measurement ;
  dbms_lock.sleep(v_delta);

  -- Second measurement
  b:=take_measurement ;

  show_result;
end;
/
EOF
echo "`date +%H'h'%M:%S`"
done
exit
# ......................................
# Remove rules sets
# ......................................
elif [ "$CHOICE" = "REMOVE_RULE_SET" ];then
  if [  -z "$RMS_TYPE" ];then
     echo "Add 'neg' or 'pos' to determine which rules to remove"
     exit
  fi
  if [ "$RMS_TYPE" = 'pos' ];then
      BOL=TRUE
  else 
      BOL=FALSE
  fi

SQL="
  col v_rs_name new_value v_rs_name  noprint
  col v_rs_owner new_value v_rs_owner  noprint
  select v_rs_name, v_rs_owner from (
  select RULE_SET_NAME v_rs_name ,RULE_SET_OWNER  v_rs_owner 
         from dba_capture where capture_name = upper('$fcapture') and 'pos' = '$RMS_TYPE'
  union
  select NEGATIVE_RULE_SET_NAME v_rs_name ,NEGATIVE_RULE_SET_OWNER v_rs_owner
          from dba_capture where capture_name = upper('$fcapture') and 'neg' = '$RMS_TYPE'
  )
  /
prompt doing exec dbms_streams_adm.remove_rule(rule_name => '&v_rs_owner.&v_rs_name', streams_type=>'capture', streams_name =>'$fcapture', inclusion_rule => $BOL );
exec dbms_streams_adm.remove_rule(rule_name => '&v_rs_owner..&v_rs_name', streams_type=>'capture', streams_name =>'$fcapture', inclusion_rule => $BOL );
"
# ......................................
# List Objects paths
# ......................................
elif [ "$CHOICE" = "LIST_DIFF" ];then
    if [ -n "$ftable" ];then
       AND_TABLE=" and table_name = '$ftable' " 
    fi
SQL="
set serveroutput on 
declare
  v_capture      varchar2(30);
  v_cap_q        varchar2(30);
  v_cap_qo       varchar2(30);
  v_prop         varchar2(30);
  v_dest_q       varchar2(30);
  v_dest_qo      varchar2(30);
  v_dblink       varchar2(30);
begin
  for c in ( select TABLE_OWNER, TABLE_NAME from dba_capture_prepared_tables where SCN is not null )
  loop

  -- Get the caputre for this table
  select STREAMS_NAME into v_capture from SYS.DBA_STREAMS_TABLE_RULES 
        where STREAMS_TYPE = 'CAPTURE' and TABLE_OWNER = c.TABLE_OWNER and  TABLE_NAME = c.TABLE_NAME ;

   dbms_output.put_line(rpad('--> Owner.Table',20,' ') || ': ' || c.table_owner||'.'|| c.table_name ) ; 
   dbms_output.put_line(rpad('--> Capture',20,' ') || ': '|| v_capture ) ;

   select QUEUE_NAME, QUEUE_OWNER into v_cap_q,v_cap_qo from sys.dba_capture where CAPTURE_NAME = v_capture ;  
   dbms_output.put_line(rpad('--> Queue name',20,' ')|| ': '||v_cap_qo||'.'||v_cap_q ) ;

   select PROPAGATION_NAME, DESTINATION_QUEUE_OWNER, DESTINATION_QUEUE_NAME, DESTINATION_DBLINK 
           into v_prop, v_dest_q, v_dest_qo, v_dblink
           from SYS.DBA_PROPAGATION where SOURCE_QUEUE_OWNER = v_cap_qo and SOURCE_QUEUE_NAME = v_cap_q;
   dbms_output.put_line(rpad('--> Propagation name',20,' ')|| ': '||v_prop ) ;
   dbms_output.put_line(rpad('--> Dblink',20,' ')|| ': '||v_dblink ) ;
   dbms_output.put_line(rpad('--> Destination queueq',20,' ')|| ': '||v_dest_qo||'.'||v_dest_q ) ;

   dbms_output.put_line('---------------------' );
   /*
   dbms_output.put_line(rpad('--> Destination queueq',20,' ')|| ': '||v_dest_qo||'.'||v_dest_q ) ;
   dbms_output.put_line(rpad('--> Destination table',20,' ')|| ': $ftarget_owner.$ftarget_table') ;
   dbms_output.put_line(rpad('--> Source diff table',20,' ')|| ': $fsource_owner.$tbl_dif1') ;
   dbms_output.put_line(rpad('--> Target diff table',20,' ')|| ': $fsource_owner.$tbl_dif2') ;
   -- First diff table
   select count(1) into v_cpt from dba_tables where owner = '$fsource_owner' and table_name = upper('$tbl_dif1');
   if v_cpt = 0 then
     v_cmd:='drop table $fsource_owner.$tbl_dif1' ;
     execute immediate v_cmd ;
     v_cmd:='create table $fsource_owner.$tbl_dif1 $TBS as select * from $fsource_owner.$ftable where 1=2';
     dbms_output.put_line(v_cmd) ;
     execute immediate v_cmd ;
     dbms_output.put_line(' table $tbl_dif1 created $TBS');
   else 
     dbms_output.put_line(' table $tbl_dif1 already exists ');
   end if;
   -- Second diff table
   select count(1) into v_cpt from dba_tables where owner = '$fsource_owner' and table_name = upper('$tbl_dif2');
   if v_cpt = 0 then
     v_cmd:='drop table $fsource_owner.$tbl_dif2' ;
     execute immediate v_cmd ;
     v_cmd:='create table $fsource_owner.$tbl_dif2 $TBS as select * from $fsource_owner.$ftable where 1=2 ';
     dbms_output.put_line(v_cmd) ;
     execute immediate v_cmd ;
     dbms_output.put_line('--> table $tbl_dif2 created $TBS');
   else 
     dbms_output.put_line(' table $tbl_dif2 already exists ');
   end if;
   dbms_rectifier_diff.differences(   
       sname1 => '$fsource_owner' ,  oname1  => '$ftable' , reference_site => v_global_name  , sname2  => '$ftarget_owner' , \
       oname2 => '$ftarget_table', comparison_site    => v_dblink, where_clause => NULL, column_list => '', \
        missing_rows_sname  => '$fsource_owner', missing_rows_oname1 => '$tbl_dif1', missing_rows_oname2 => '$tbl_dif2', \
       missing_rows_site  => '', max_missing => 10000000, commit_rows => 500 );
   dbms_output.put_line('v_cmd='||v_cmd);
   execute immediate v_cmd ;
   */
  end loop;
end;
/
"
# ......................................
# Remove transaction in v$streams_transaction 
# ......................................
elif [ "$CHOICE" = "REMOVE_TX" ];then
SQL="
prompt WARNING:
prompt You must stop capture before remove TX and restat when it is done
prompt
prompt Doing execute dbms_capture_adm.set_parameter('$fcapture','_ignore_transaction','$TX_ID');;
execute dbms_capture_adm.set_parameter('$fcapture','_ignore_transaction','$TX_ID');
"
# ......................................
# List transaction in v$streams_transaction 
# ......................................
elif [ "$CHOICE" = "LIST_TX" ];then
SQL="set lines 190 pages 66
col Streams_type head 'Streams|Type'
col CUMULATIVE_MESSAGE_COUNT head 'LCR since|start TX' justify l
col FIRST_MESSAGE_TIME for a19 head 'First LCR|Time' justify l
col LAST_MESSAGE_TIME for a19 head 'Last LCR|Time' justify l
col fn for 99999999999 head 'SCN at start of TX'
col ln for 99999999999 head 'Last SCN in this TX'
col tx_id for a16
select streams_name,streams_type, to_char(XIDUSN)||'.'||to_char(XIDSLT)||'.'||to_char(XIDSQN) tx_id,
      CUMULATIVE_MESSAGE_COUNT, 
      to_char(FIRST_MESSAGE_TIME,'YYYY-MM-DD HH24:MI:SS') FIRST_MESSAGE_TIME,
      to_char(last_MESSAGE_TIME,'YYYY-MM-DD HH24:MI:SS') last_MESSAGE_TIME
     -- ,FIRST_MESSAGE_NUMBER fn , LAST_MESSAGE_NUMBER ln
       from V\$STREAMS_TRANSACTION ;"
# ......................................
# List Logminser sessions
# ......................................
elif [ "$CHOICE" = "LIST_SES" ];then
SQL="col SESSION_NAME format a20
select SESSION_NAME, SESSION#, CLIENT#, START_SCN, END_SCN , 
       SPILL_SCN,SPILL_TIME,OLDEST_SCN,RESUME_SCN
    from system.LOGMNR_SESSION\$
/"
# ......................................
# Export the dictionary to redo
# ......................................
elif [ "$CHOICE" = "BUILD" ];then
SQL="set serveroutput on 
variable f_scn number; 
begin 
:f_scn := 0; 
dbms_capture_adm.build(:f_scn); 
dbms_output.put_line('the first_scn value is ' || :f_scn); 
end; 
/
"
# ......................................
# List archives with built in dictionary above the first SCN
# ......................................

elif [ "$CHOICE" = "LSTB" ];then
SQL="prompt The following archives is suitable new first_scn for capture. If name is empty then archive is not more on disk
prompt
col first_change# head SCN
col name format a80
set lines 190 
select sequence#, first_change#,FIRST_TIME, name from v\$archived_log 
    where DICTIONARY_BEGIN =  'YES' and first_change# > (select min(first_scn) from dba_capture) 
    order by FIRST_TIME desc ;
"
# ......................................
# Purge Logminer CKPT
# ......................................

elif [ "$CHOICE" = "PURGE_CKP" ];then

   if [ -z "$fcapture" ];then
        var=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off pagesize 0 
select count(*) cpt from dba_capture;
EOF`
        cpt=`echo $var|awk '{print $1}'`
        if [ "$cpt" = "1" ];then
           fcapture=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off pagesize 0 
select capture_name from dba_capture;
EOF`
         else
           echo "You need to add -cn <capture_name>"
           exit
        fi
   fi
   
SQL="set serveroutput on 
  prompt Before : 
  prompt
  set head on
  select /*+ index_ffs(a LOGMNR_RESTART_CKPT\$_PK) */ count(*) from system.LOGMNR_RESTART_CKPT\$ a ;
DECLARE
 hScn number := 0;
 lScn number := 0;
 sScn number;
 ascn number;
 alog varchar2(1000);
 v_session number;
begin
  select min(start_scn), min(applied_scn) into sScn, ascn from dba_capture where capture_name = '$fcapture' ;
  select logminer_id into v_session from  dba_capture where capture_name = '$fcapture' ;
  -- DBMS_OUTPUT.ENABLE(2000);
  for cr in (select distinct(a.ckpt_scn) from system.logmnr_restart_ckpt\$ a
                    where a.ckpt_scn <= ascn and a.valid = 1 and session# = v_session 
                      and exists (select * from system.logmnr_log\$ l where a.ckpt_scn between l.first_change# and l.next_change#) order by a.ckpt_scn desc)
  loop
    if (hScn = 0) then
       hScn := cr.ckpt_scn;
    else
       lScn := cr.ckpt_scn;
       exit;
    end if;
  end loop;

  if lScn = 0 then
    lScn := sScn;
  end if;
  dbms_output.put_line('dbms_capture_adm.alter_capture( capture_name => ''$fcapture'',first_scn=> ' ||to_char(lScn)||');') ;
  dbms_capture_adm.alter_capture( capture_name => '$fcapture',first_scn=> lScn );
end;
/
  prompt After : 
  prompt
  set head on
  select /*+ index_ffs(a LOGMNR_RESTART_CKPT\$_PK) */ count(*) from system.LOGMNR_RESTART_CKPT\$ a ;
  prompt
"
# ......................................
# List logminer tables contents
# ......................................

elif [ "$CHOICE" = "GM" ];then
SQL="
set serveroutput on 
declare

var number:=0 ;
begin

for t in (select table_name from dba_tables where owner = 'SYSTEM' and table_name like 'LOGM%'order by table_name)
loop
   execute immediate('select count(*) from system.' || t.table_name) into var ;
   dbms_output.put_line(t.table_name ||':' || to_char(var));
end loop ;
end ;
/
"
# ......................................
# List logminer sessions
# ......................................

elif [ "$CHOICE" = "LIST_LG" ];then
  if [ -n "$LOGMNR_ID" ];then
       WHERE_LOGMNR_ID=" where SESSION_ID = $LOGMNR_ID "
   fi

SQL="col ROLE format a16 
col SESSION_ID format 99999 head 'Logmr|id' justify c
col WORK_MICROSEC format 9999990.99 head 'Work(sec)'
col OVERHEAD_MICROSEC format 9999990.99 head 'Waiting or|Overead (sec)' justify c
col ROLE format a22
col SID for 99999
col latchwait head 'Address latch|Process waiting'
col latchspin head 'Address latch|Process spinning'
set lines 190
select SESSION_ID, ROLE ,SID, spid ,
       WORK_MICROSEC/1000000 WORK_MICROSEC,
       OVERHEAD_MICROSEC/1000000 OVERHEAD_MICROSEC ,
LATCHWAIT,LATCHSPIN
   from  V\$LOGMNR_PROCESS $WHERE_LOGMNR_ID
 order by session_id
  ;
"
# ......................................
# Remove streams configuration
# ......................................

elif [ "$CHOICE" = "RCFG" ];then
   if $SBIN/scripts/yesno.sh "to remove streams configuration"
   then
     EXECUTE=YES
     SQL="prompt Doing exec dbms_streams_adm.remove_streams_configuration;;
exec dbms_streams_adm.remove_streams_configuration;"
   else
    SQL="prompt cancelled"
fi

# ......................................
#  Shrink and analyse table system.logmnr_restart_ckpt\$
# ......................................

elif [ "$CHOICE" = "SHRINK" ];then
$SBIN/module2/s4/smenu_desc_table.ksh -u system -t logmnr_restart_ckpt\$
sqlplus -s "$CONNECT_STRING" <<EOF
set time on
prompt After purge of table, do :
prompt
prompt alter table system.LOGMNR_RESTART_CKPT\$ enable row movement ;; 
alter table system.LOGMNR_RESTART_CKPT\$ enable row movement ;

prompt alter table system.LOGMNR_RESTART_CKPT\$ shrink space ;; 
alter table system.LOGMNR_RESTART_CKPT\$ shrink space ;

prompt alter table system.LOGMNR_RESTART_CKPT\$ disable row movement ;; 
alter table system.LOGMNR_RESTART_CKPT\$ disable row movement ;
EOF
echo "Start of analysis"
$SBIN/module3/s6/smenu_gather_stat_tbl.ksh -u system -t logmnr_restart_ckpt\$ -c -x
$SBIN/module2/s4/smenu_desc_table.ksh -u system -t logmnr_restart_ckpt\$

# ......................................
# Count rows in system.logmnr_restart_ckpt$ 
# ......................................

elif [ "$CHOICE" = "COUNT" ];then
$SBIN/module2/s4/smenu_desc_table.ksh -u system -t logmnr_restart_ckpt\$
sqlplus -s "$CONNECT_STRING" <<EOF
prompt After purge of table, do :
prompt alter table system.LOGMNR_RESTART_CKPT\$ enable row movement ;; 
prompt alter table system.LOGMNR_RESTART_CKPT\$ shrink space ;; 
prompt alter table system.LOGMNR_RESTART_CKPT\$ disable row movement ;; 

set linesize 190 pagesize 66 pause off feed off head on
col archive format a14 head 'Thread and |archive num'
 select distinct  thread#,min_scn, scn_date, total_rows, to_char(THREAD#) ||'_'||to_char(SEQUENCE#) archive
         from
           gv\$archived_log a,
   (
select min_scn, scn_date, total_rows from (
     select min_scn,
       (select to_char(scn_to_timestamp(min_scn),'HH24:MI:SS DD-MM-YY') from dual) scn_date ,
       (select count(*)  from system.logmnr_restart_ckpt\$) total_rows
     from (
        select min(CKPT_SCN) min_scn from system.logmnr_restart_ckpt\$ where valid=1)
    )
    ) b
where min_scn between FIRST_CHANGE# and NEXT_CHANGE#
/
EOF
exit
# ......................................
# Reset SCN
# ......................................
elif [ "$CHOICE" = "RESET_SCN" ];then
  $SCN=${SCN:-0}
SQL="
set serveroutput on 
declare
  fscn number;
  ascn number;
  rscn number;
  sscn number := $SCN ;
begin
    SELECT FIRST_SCN, APPLIED_SCN, REQUIRED_CHECKPOINT_SCN into fscn,ascn,rscn 
           FROM DBA_CAPTURE where CAPTURE_NAME = upper('$fcapture');
    if fscn > ascn then
       fscn := ascn ;
    end if;
    if fscn > rscn then
       fscn := rscn ;
    end if;
    if sscn < fscn then
       sscn := fscn-1;
    end if ;
    dbms_output.put_line('dbms_capture_adm.alter_capture(capture_name => ''$fcapture'',first_scn=>'||to_char(fscn)||',start_scn=>'||to_char(sscn)||'); ');
    dbms_capture_adm.alter_capture( capture_name => '$fcapture',first_scn=> fscn,start_scn=>sscn );
    
end;
/
"
# ......................................
# List capture rule
# ......................................
elif [ "$CHOICE" = "GET_CURR_SCN" ];then
SQL="
           set serveroutput on 
           DECLARE
            iscn NUMBER; -- Variable to hold instantiation SCN value
           BEGIN
            iscn := DBMS_FLASHBACK.GET_SYSTEM_CHANGE_NUMBER();
            DBMS_OUTPUT.PUT_LINE ('Instantiation SCN is: ' || iscn);
           END;
/
"
# ......................................
# List capture rule
# ......................................
elif [ "$CHOICE" = "CAP_RUL" ];then
SQL="set long 4000
select rsr.rule_set_owner||'.'||rsr.rule_set_name rsn ,rsr.rule_owner||'.'||rsr.rule_name rn,
r.rule_condition rt from dba_rule_set_rules rsr, dba_rules r where rsr.rule_name = r.rule_name and rsr.rule_owner = r.rule_owner and rule_set_name in (select
rule_set_name from dba_capture) order by rsr.rule_set_owner,rsr.rule_set_name;"
# set trace
# ......................................
elif [ "$CHOICE" = "TRACE" ];then
# ......................................
 SQL="execute dbms_capture_adm.set_parameter(capture_name=> '$fcapture' , parameter=> 'trace_level', value => $trace_level); "

# ......................................
# List capture Parameters
# ......................................
elif [ "$CHOICE" = "PARAMETERS" ];then
# ......................................
SQL="break on capture_name on report
col CAPTURE_NAME format a25
col PARAMETER format a30
col value format a30
col SET_BY_USER format a12
select CAPTURE_NAME,PARAMETER, VALUE, SET_BY_USER from SYS.DBA_CAPTURE_PARAMETERS ;
prompt List suplementatl logging setting: IMPLICIT means it is acitivated for this type
col log_data_pk format a12
col log_data_fk format a12
col log_data_ui format a12
col log_data_all format a12

prompt
select SCHEMA_NAME, TIMESTAMP, SUPPLEMENTAL_LOG_DATA_PK log_data_pk, SUPPLEMENTAL_LOG_DATA_UI log_data_ui,
       SUPPLEMENTAL_LOG_DATA_FK log_data_fk, SUPPLEMENTAL_LOG_DATA_ALL log_data_all from DBA_CAPTURE_PREPARED_SCHEMAS ;
"
# ......................................
# List Checkpoints
# ......................................
elif [ "$CHOICE" = "LIST_LCK" ];then
cat <<EOF


====================
Oracle definitions:
====================
First SCN : The first SCN is the lowest SCN in the redo log from which a capture process can capture changes. 
            If you specify a first SCN during capture process creation, then the database must be able to access 
            redo data from the SCN specified and higher.

Start SCN : The start SCN is the SCN from which a capture process begins to capture changes. You can specify a start SCN 
            that is different than the first SCN during capture process creation, or you can alter a capture process to set 
            its start SCN. The start SCN does not need to be modified for normal operation of a capture process. Typically, 
            you reset the start SCN for a capture process if point-in-time recovery must be performed on one of the destination 
            databases that receive changes from the capture process. In these cases, the capture process can be used to capture 
            the changes made at the source database after the point-in-time of the recovery.

Required Checkpoint SCN  : The SCN that corresponds to the lowest checkpoint for which a capture process requires redo data 
            is the required checkpoint SCN. If a capture process is stopped and restarted, then it starts scanning the redo log 
            from the SCN that corresponds to its required checkpoint SCN. The required checkpoint SCN is important for recovery 
            if a database stops unexpectedly. Also, if the first SCN is reset for a capture process, then it must be set to a value 
            that is less than or equal to the required checkpoint SCN for the captured process. You can determine the required checkpoint 
            SCN for a capture process by querying the REQUIRED_CHECKPOINT_SCN column in the DBA_CAPTURE data dictionary view.

Instantiation SCN  : The system change number (SCN) for a table which specifies that only changes that were committed after the SCN 
            at the source database are applied by an apply process.

Checkpoint_retention_time : Controls the amount of days of metadata retained by moving  FIRST_SCN  forward

          First scn must be <= Start Scn
          First scn must be <= applied scn (only when applied scn > 0)
          First scn must be <= required chkpoint SCN
EOF
TITTLE="Report Streams SCN positioning"
SQL="break on capture_name on report
col start_scn for 999999999999 head 'Start scn'
col first_scn for 999999999999 head 'First scn'
col CAPTURED_SCN for 999999999999 head 'Captured scn'
col las for 999999999999 head 'Applied scn'
col LAST_ENQUEUED_SCN for 999999999999 head 'Last scn|Enqueued' justify c
col REQUIRED_CHECKPOINT_SCN for 999999999999 head 'Required |Checkpoint scn' justify c
col MAX_CHECKPOINT_SCN for 999999999999 head 'Max |Checkpoint scn' justify c
col capture_name for a22 head 'Capture name'
set linesize 150
select CAPTURE_NAME, FIRST_SCN, start_scn, APPLIED_SCN las, CAPTURED_SCN, CHECKPOINT_RETENTION_TIME, LAST_ENQUEUED_SCN,
         REQUIRED_CHECKPOINT_SCN, MAX_CHECKPOINT_SCN from SYS.DBA_CAPTURE;
"

# ......................................
# List archive purge status 
# ......................................
elif [ "$CHOICE" = "REGISTERED" ];then
SQL="set linesize 150
break on consumer_name on report
col consumer_name format a23
col name format a55
col sequence# for 999999 head 'Arch#'
col first_scn for 999999999999
col R noprint
     select consumer_name,SEQUENCE# , FIRST_SCN , to_char(FIRST_TIME,'MM-DD HH24:MI:SS') first_time, name,
            PURGEABLE,DICTIONARY_BEGIN, DICTIONARY_END , r
    from (
     select consumer_name,SEQUENCE# , FIRST_SCN , FIRST_TIME, name,
            PURGEABLE,DICTIONARY_BEGIN, DICTIONARY_END , row_number() over (order by  FIRST_TIME desc, thread#) r
     from SYS.DBA_REGISTERED_ARCHIVED_LOG
) where r between 1 and $ROWNUM
order by  SEQUENCE# desc ;
"
# ......................................
# List capture server status
# ......................................
elif [ "$CHOICE" = "CAPTURE_SERVER" ];then
   SQL="col state format a19
select CAPTURE_NAME cap, state,ELAPSED_CAPTURE_TIME ect,ELAPSED_ENQUEUE_TIME eet,ELAPSED_LCR_TIME elt, CAPTURE_MESSAGE_NUMBER cmn ,ENQUEUE_MESSAGE_NUMBER emn, total_messages_captured tmc, TOTAL_MESSAGES_ENQUEUED tme from v\$streams_capture 
/
select CAPTURE_NAME cap,to_char(STARTUP_TIME,'MM/DD HH24:MI:SS') startup, to_char(CAPTURE_TIME,'MM/DD HH24:MI:SS') lct, 
       to_char(CAPTURE_MESSAGE_CREATE_TIME,'MM/DD HH24:MI:SS') cmct, to_char(ENQUEUE_TIME,'MM/DD HH24:MI:SS')ltme,
       to_char(ENQUEUE_MESSAGE_CREATE_TIME,'MM/DD HH24:MI:SS') emct from v\$streams_capture
/
"
# ......................................
# Set checkpoint frequency
# ......................................
elif [ "$CHOICE" = "LOGMINER" ];then
    # bpa : in 10g this is also good 
    # SELECT NVL(MAX(A.SPARE1), 0) FROM SYSTEM.LOGMNR_RESTART_CKPT$ A WHERE A.SESSION# = :b AND A.VALID = 1 AND EXISTS 
    #  (SELECT B.CKPT_SCN FROM SYSTEM.LOGMNR_RESTART_CKPT$ B WHERE B.CKPT_SCN = A.SPARE1 AND B.SESSION# = A.SESSION# AND B.VALID = 1)
   if [ -n "$LOGMNR_ID" ];then
       WHERE_LOGMNR_ID=" where LOGMINER_ID = $LOGMNR_ID "
       AND_LOGMNR_ID=" and session# = $LOGMNR_ID "
   fi
   SQL=" set serveroutput on
DECLARE
 hScn number := 0;
 lScn number := 0;
 sScn number;
 ascn number;
 alog varchar2(1000);
begin
  select min(start_scn), min(applied_scn) into sScn, ascn
    from dba_capture $WHERE_LOGMNR_ID;

  DBMS_OUTPUT.ENABLE(2000); 

  for cr in (select distinct(a.ckpt_scn)
             from system.logmnr_restart_ckpt\$ a
             where a.ckpt_scn <= ascn and a.valid = 1 $AND_LOGMNR_ID
               and exists (select * from system.logmnr_log\$ l
                   where a.ckpt_scn between l.first_change# and
                     l.next_change#)
              order by a.ckpt_scn desc)
  loop
    if (hScn = 0) then
       hScn := cr.ckpt_scn;
    else
       lScn := cr.ckpt_scn;
       exit;
    end if;
  end loop;

  if lScn = 0 then
    lScn := sScn;
  end if;
   -- select min(name) into alog from v\$archived_log where lScn between first_change# and next_change#;
  -- dbms_output.put_line('Capture will restart from SCN ' || lScn ||' in log '||alog);
    dbms_output.put_line('Capture will restart from SCN ' || lScn ||' in the following file:');
   for cr in (select name, first_time  , SEQUENCE#
               from DBA_REGISTERED_ARCHIVED_LOG 
               where lScn between first_scn and next_scn order by thread#)
  loop

     dbms_output.put_line(to_char(cr.SEQUENCE#)|| ' ' ||cr.name||' ('||cr.first_time||')');
  end loop;


end;
/
"

# ......................................
# Set SGA_SIZE
# ......................................
elif [ "$CHOICE" = "SET_SGA" ];then
   SQL="execute dbms_capture_adm.set_parameter(capture_name=> '$fcapture' , parameter=> '_SGA_SIZE', value => ${sga_size}); "

# ......................................
# Set checkpoint frequency
# ......................................
elif [ "$CHOICE" = "CHECK_FREQ" ];then
   SQL="execute dbms_capture_adm.set_parameter(capture_name=> '$fcapture' , parameter=> '_CHECKPOINT_FREQUENCY', value => $check_freq); "

# ......................................
# Set retention checkpoint time
# ......................................
elif [ "$CHOICE" = "SET_RET" ];then
   SQL="execute dbms_capture_adm.alter_capture(capture_name=> '$fcapture' , checkpoint_retention_time=> $value ); "
elif [ "$CHOICE" = "SET_PAR" ];then
   SQL="execute dbms_capture_adm.set_parameter(capture_name=> '$fcapture' , parameter=> '$PAR', value => $value); "

# ......................................
# Table prepared for instantion
# ......................................
elif [ "$CHOICE" = "TBL_INS" ];then
   if [ -n "$fowner" ];then
       WHERE=" where TABLE_OWNER=upper('$fowner')"
   fi
   BREAK="break on table_owner"
   SQL="
prompt Type cap -lck to see capture start scn
prompt
select TABLE_OWNER, TABLE_NAME,SCN,
       to_char(TIMESTAMP,'DD-MM-YYYY HH24:MI:SS') ti 
from dba_capture_prepared_tables  $WHERE
order by table_owner;"
# ......................................
# Show lowest prepared SCN
# ......................................
elif [ "$CHOICE" = "MIN_SI" ];then
    if [ -n '$fowner' ];then
         WHERE_OWNER=" where table_owner=upper('$fowner') "
         AND_OWNER=" and table_owner=upper('$fowner') "
    fi
    BREAK="break on table_owner"
    SQL="prompt Type cap -lck to see capture start scn
 prompt
 select TABLE_OWNER,TABLE_NAME,SCN min_scn,to_char(TIMESTAMP,'DD-MM-YYYY HH24:MI:SS') ti
        from dba_capture_prepared_tables where  scn = (select min(scn) from dba_capture_prepared_tables $WHERE_OWNER) $AND_OWNER;"
# ......................................
# Create capture process
# ......................................
elif [ "$CHOICE" = "CREATE" ];then
   if [ -n "$frsname" ];then
      SQL="execute DBMS_CAPTURE_ADM.CREATE_CAPTURE(queue_name => '$fowner.$fqueue', capture_name => '$fcapture', rule_set_name => '$fowner.$frsname');"
   fi
# ......................................
# List capture process
# ......................................
elif [ "$CHOICE" = "LIST" ];then
    if [ -n "$fcapture" ];then
          AND_CAPTURE_NAME=" and capture_name = upper('$fcapture') "
          AND_CAPTURE_NAME_A=" and a.capture_name = upper('$fcapture') "
          WHERE=" where 1=1"
    elif [ -n "$LOGMNR_ID" ];then
       AND_LOGMNR_ID="  and LOGMINER_ID = $LOGMNR_ID "
       AND_LOGMNR_ID_A=" and a.LOGMINER_ID = $LOGMNR_ID "
       WHERE=" where 1=1"
   fi
    SQL="
col LOGMINER_ID head 'Log|ID'  for 999
select  LOGMINER_ID, CAPTURE_USER,  start_scn ncs,  to_char(STATUS_CHANGE_TIME,'DD-MM HH24:MI:SS') change_time 
    ,CAPTURE_TYPE,RULE_SET_NAME, negative_rule_set_name , status from dba_capture $WHERE $AND_CAPTURE_NAME $AND_LOGMNR_ID
order by logminer_id
/
set lines 190
col rsname format a22 head 'Rule set name'
col delay_scn head 'Delay|Scanned' justify c
col delay2 head 'Delay|Enq-Applied' justify c 
col state format a24
col process_name format a8 head 'Process|Name' justify c
col LATENCY_SECONDS head 'Lat(s)'
col total_messages_captured head 'total msg|Captured'
col total_messages_enqueued head 'total msg|Enqueue'
col ENQUEUE_MESG_TIME format a17 head 'Row creation|initial time'
col CAPTURE_TIME head 'Capture at'
col queue_name for a30
select a.logminer_id , a.CAPTURE_NAME cap, queue_name , AVAILABLE_MESSAGE_NUMBER, CAPTURE_MESSAGE_NUMBER lcs, 
      AVAILABLE_MESSAGE_NUMBER-CAPTURE_MESSAGE_NUMBER delay_scn,
      last_enqueued_scn , applied_scn las , last_enqueued_scn-applied_scn delay2
      from dba_capture a, v\$streams_capture b where a.capture_name = b.capture_name (+) $AND_CAPTURE_NAME_A $AND_LOGMNR_ID_A
order by logminer_id
;
SELECT c.logminer_id,
         SUBSTR(s.program,INSTR(s.program,'(')+1,4) PROCESS_NAME,
         c.sid,
         c.serial#,
         c.state,
         to_char(c.capture_time, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,
         to_char(c.enqueue_message_create_time,'HH24:MI:SS MM/DD/YY') ENQUEUE_MESG_TIME ,
        (SYSDATE-c.capture_message_create_time)*86400 LATENCY_SECONDS,
        c.total_messages_captured,
        c.total_messages_enqueued
   FROM V\$STREAMS_CAPTURE c, V\$SESSION s
   WHERE c.SID = s.SID $AND_CAPTURE_NAME  $AND_LOGMNR_ID
  AND c.SERIAL# = s.SERIAL#
order by logminer_id ;

set head off 
select ERROR_MESSAGE from dba_capture;"

# ......................................
# abort instantiation
# ......................................
elif [ "$CHOICE" = "ABORT_INSTANTIATE" ];then
  if [ -n "$ftable" ];then
     if [ -z "$fsource_owner" ];then
        echo "I need the table owner, user 'cap -abort -so OWNER -t TABLE'"
        exit
     fi
     SQL="execute  DBMS_CAPTURE_ADM.${ACTION}_TABLE_INSTANTIATION( table_name  => '$fsource_owner.$ftable'); "
  elif [ -n "$fsource_owner" ];then
     SQL="execute  DBMS_CAPTURE_ADM.${ACTION}_SCHEMA_INSTANTIATION( schema_name  => '$fsource_owner'); "
  else
    echo "Need to be more precise for instantiation : give a owner or owner+table name"
    exit
  fi

# ......................................
# Prepare instantiation
# ......................................
elif [ "$CHOICE" = "PREPARE" ];then
  if [ -z "$fsource_owner" ];then
     echo "I need a schema, use 'cap -so OWNER'"
     exit
  fi
  if [ -z "$ftable" ];then
     SQL="execute  DBMS_CAPTURE_ADM.PREPARE_SCHEMA_INSTANTIATION( schema_name  => '$fsource_owner'); "
  else
     src_sid=${src_sid:-$ORACLE_SID}
     SQL="show user
prompt execute dbms_capture_adm.prepare_table_instantiation('$fsource_owner.$ftable') ;
execute DBMS_CAPTURE_ADM.PREPARE_TABLE_INSTANTIATION(table_name => '$fsource_owner.$ftable');
"
  fi

# ......................................
# Start / stop / drop capture
# ......................................
elif [ "$CHOICE" = "START_STOP_DROP" ];then
  SQL=" execute  DBMS_CAPTURE_ADM.${ACTION}_CAPTURE( capture_name => '$fcapture');"
fi
if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi

