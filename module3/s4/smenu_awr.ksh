#!/bin/sh
# set -xv
# author :  B. Polarski
# 26 October 2007
# program smenu_awr.ksh
# Modified : 17 Jun 2009    Added the get_hash_Value function
#            06 Dec 2010    Added DBID on all queries

ROWNUM=50
SHEAD="ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 150 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,13)  || '  $TITTLE  ' nline
from sys.dual
/
"
# ......................................................................................................
function get_last_snap
{
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select max(snap_id) from sys.wrm\\$_snapshot where instance_number   = 1 and dbid= '$DBID' ;
EOF`
 echo "$ret"| tr -d '\r'| awk '{print $1}'
}
# ......................................................................................................
function get_snap_start
{
 SNAP=$1 
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select to_char(BEGIN_INTERVAL_TIME,'YYYY-MM-DD HH24:MI:SS') from sys.wrm\\$_snapshot where instance_number   = 1 and dbid= '$DBID' and snap_id=$SNAP;
EOF`
 echo "$ret"| tr -d '\r'
 #echo "$ret"| tr -d '\r'| awk '{print $1}'
}
# ......................................................................................................
function exists_binds
{
 unset ret
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select count(*) from dba_hist_sqlbind where sql_id = '$SQL_ID' $AND_DBID  $AND_SNAP1;
EOF`
 ret=${ret:-0}
 ret=`echo $ret | tr -d '\n' | tr -d '\r'`
 if [ $ret -eq 0 ];then
     ret=`sqlplus -s "$CONNECT_STRING" <<EOF
             set head off pagesize 0 feed off verify off
            select count(*) from dba_hist_sqlbind where sql_id = '$SQL_ID' $AND_DBID ;
EOF`
     ret=`echo $ret | tr -d '\n' | tr -d '\r'`
     if [ $ret -gt 0 ];then
        var=`sqlplus -s "$CONNECT_STRING" <<EOF
            set head on pagesize 66 feed off verify off
             select * from ( select snap_id from dba_hist_sqlbind where sql_id = '$SQL_ID' $AND_DBID ) where rownum <= $ROWNUM;
EOF`
        ret="-1 

Total_number_of_snap_with_binds:$ret
$var"
     fi
 fi
 ret=${ret:-0}
    
 echo "$ret"| tr -d '\r'| awk '{print $1}'
}
# ---------------------------------------------------------------------------
function do_sql
{
if [ "$EXECUTE" = "NO" ];then
   echo "\n\nAdd -x to execute. This command will then be executed:\n"
   echo "$SQL"
   echo
   exit
fi
if [ -n "$VERBOSE" ];then
   echo "$SQL"
fi
if [ "$NO_HEADER" = TRUE ];then
    SHEAD='set feed off'
fi
if [ -n "$FOUT" ];then
    sqlplus -s "$CONNECT_STRING"  >$FOUT  2>&1 <<EOF
$SHEAD

break on task_name on command
set head on
col owner format a18
col name format a30
col version format a10
col detected_usages format 999999 head "Detected|usages" justify c
col description format a85
col instance_number for 99 head 'In|st' justify l
$SQL
EOF
  cat $FOUT
else
    # no output files given
    sqlplus -s "$CONNECT_STRING"   <<EOF
$SHEAD

break on task_name on command
set head on
col owner format a18
col name format a30
col version format a10
col detected_usages format 999999 head "Detected|usages" justify c
col description format a85
col instance_number for 99 head 'In|st' justify l
$SQL
EOF
fi
}
# ---------------------------------------------------------------------------
function get_sql_id
{
 if [ -z "${1%%*[a-z]*}" ];then
    # $1 is a mix of digit and alpha
    echo "$1"
    return
 fi
 # $1 is a hash_value made of only digit
 ret=`sqlplus -s "$CONNECT_STRING" <<EOF
 set head off pagesize 0 feed off verify off
 select distinct sql_id from sys.${G}v_\\$sql where hash_value = '$1';
EOF`
 echo "$ret" | tr -d '\r'
}
# ---------------------------------------------------------------------------
function help
{
cat  <<EOF
                                           Work with AWR:
                                           --------------
AWR:

    aw -l -rn <nn>  [-dbid <nn>]             : List last available snap, limit to -rn <ROWS>  default is last 30
    aw -sn <snap_id>                         : show date for snape for snap_id 
    aw -lret                                 : Show retention/interval  period              
    aw -set <retentions> <interval>          : Set the retention period and the interval (both expressed in minutes)
    aw -xx                                   : take an awr snap                                  
    aw -lsdb                                 : list DBID presents in the AWR repository          
    aw -use                                  : Show AWR options with licences used               
    aw -purge -b <beg_snap> -e <end_snap>    : Purge AWR snapshots
    aw -dpurge <nn>                          : purge AWR snapshots older than <nn> days
    aw -io_load [-b <beg_snap> -e <end_snap>]: Show io load

SQL: 

    aw -sll -b -wait <n>  -wait              : Same as -sl but limit scope to last snap
    aw -sl -b <nn> -e<nn> -wait -rn <nn>     : List the <n> most instensive sql in worload repository
    aw -each -b <nn> -e<nn>                  : Perform 'sl -b' foreach snap_id between -b and -e
    aw -s <sqlid> -b <nn> [-e <nn>] [-html]  : Produce AWR report between -b <nn> and -e <nn> snaps for a given sql_sid
    aw -f <sqlid>                            : List snapshots where sqlid appear
    aw -pl <plan_hash value> [-b <nn>][-comp]: Show SQL plan for a given plan_hash_value
    aw -pl <sql_id> -comp                    : list all plan present in AWR for given sid, use compact mode (-comp)
    aw -lpt <TABLE> -u <user>
    aw -xpf  [-b <nn> -e <nn>]               : Show descrepancies between AWR and V$SQL for plan_hash_value 
    aw -pf  <sqlid> -b <nn> rn <nn>        : show SQL performance from -b <snap_id> down to -rn <nn> snaps. Default for -b is (now-24) and rn=24
    aw -lb <sqlid> -rn <nn>                  : List binds for sql_id limit to <nn> rows. 
    aw -sgen <hash_value|sql_id>             : sql text +  binds captured 
    aw -st <sql_id>                          : sql text for a given SQL_ID
    aw -str <sql text>                       : List sql present in AWR with this <sql text>

SESSIONS:

    aw -slc -b <snap_id> -sid <n> -len<nn>   : List Session costing 
    aw -sla -b <snap_id> -sid <n> -len<nn>   : List Session events and waits 
    aw -slk -b <snap_id> -sid <n> -len<nn>   : List Session lock tree , len of SQL text is given by -len<nn>, default 35
    aw -slp -b <snap_id> -sid <n>            : Session events and waits  wihtout session tree
    aw -sa <sid> -ser <serial> -ptext -b <snap_id>  : List event and waits for a given session
    aw -ash  -sid <sid>                      : produce ASH Spot report in text for the session sid since its logon
    aw -se [event]                           : List events from sessions hist

STATISTICS & EVENT:

    aw -ev -owt -owc [-cl <class>] [-name <event name>] -b <nn> -e <nn>: List events from sessions hist
    aw -lbw                                  : Buffer busy wait for last snap 
    aw -bbw  -b <nn> -e <nn>                 : List Buffer busy wait for the last day or hour   
    aw -rdl -b <nn> -e <nn>                  : Show LGWR and redo related stats
    aw -lst -b <nn> -e <nn>                  : DB stats out of AWR               
    aw -lsi -b <nn> -e <nn>                  : Display metric stats history out of AWR
    aw -gn <MID>                             : Group by metric stat  for a given MID
    aw -met                                  : available metric (useful for aw -gn <MID>)
    aw -lsm                                  : List last metrics
    aw -io -b <nn> -e <nn>[-tb <tablespace>] : List tablespace and file# IO statistics, optionally limited to a single tablespace
    aw -evh -name <event>  -b <n> -e <n>     :  List event histogram
    aw -pga -b <n> -e<n>                     : List values from dba_hist_pgastat
    aw  -hist -u  <OWNER> [-t<table>] 
         -b <beg snap> -e <end snap>         : List the history stats for a table
    aw -sts                                  : List statistics deviance


AWR REPORTS:

    aw -r  [ -html ]                         : Produce AWR report for the last snap period, optionally output in html
    aw -r -b <nn> -e <nn> [ -html ]          : Produce AWR report between -b <nn> and -e <nn> snaps
    aw -dif [-b <nn>] [-e <nn>]
            [-b2 <nn>] [-e2 <nn>] [ -html ]  : Produce differential AWR report between -b1 <nn> and -b2 <nn> 

Advisor & baselines
    aw -lbs -rn <nn>                         : List baselines
    aw -tr <sql_id> [-b <nn> -e <nn>]        : Run the sqltune advisor for <sql_id>. if -b is omited then the sql stats are 
                                               taken from v\$sql otherwise they are taken from awr repository between given snap
    aw -ad  [-b <nn> -e <nn>]                : Run the database adivisor over a period. if -b is omited then the sql stats are the last one

SQL profiles:
    aw -lprf  [SQL_PRF]                      : List sql profiles from dba_ADVISOR_TASK whose radical is <SQL_PRF>. Default is SQL_PRF%
    aw -llprf  <TASK>                        : Show report for TASK. use 'aw -lprf' to get the task name
    aw -cr_prf  <sqlid> [-b <nn> -e <nn>]    : Generate sql profile for <sql id>. if -b and -e added then use data between these 2 snaps
    aw -tr_prf  -so <sql_id> -pv <plan> -sta <sql_id> [-b <nn> -e <nn>]    : Generate sql profile for -sta <sql id> using plan of -so <sql_id>

Miscel:
    aw -k -b <nn> -e <nn>                    : List table to keep using stats from snapid -b to -e <nn>


Notes :   -b  <beg_snap_id> : Start snapid, use aw -l to get snaps id                             | -s <sql_id> : id of an sql as found in  v\$sql
         -e2  <end snap>    : End snap id for second period. default to b2+1                      | -rn  <nn>   : Restrict select to <nn> rows
         -e   <end_snap_id> : End snapid, use aw -l to get snaps id ( if -e <nn> is omited, then it default to -b <nn +1> )
         -b2  <beg snap>    : Begin snap id for second period. Used in comparison. if it is omitted, default End snapid of first period + 1 
         -html              : Used for report to general html format rather than text format report
         -wait              : change the core fields from figures  exec/buff/read to waits figures -v : Verbose
         -reads             : to display reads stats for '-sl  -sll -each'
         -writes            : to display writes stats for '-sl  -sll -each'

Example : 
          aw -sll                    : List the most heaviest sql for the last AWR snapshot
          aw -sl -b 155 -e 160 -wait : List the most heaviest sql for period between snap_id 155 and snap_id i60
                                       if -wait is ommited, default output is exec/buff/read otherwise it is about waits
          aw -s <sql_id>             : Extract SQL plan and stats for <sql_id> using last 2 snaps id
          aw -s <sql_id> -ot         : Extract SQL outlines 
          aw -s <sql_id> -ot  -ph <plan_hash_value>          : Extract SQL outlines for a given plan 


          aw -dif -html              : Take the difference of the last 2 snap period
          aw -dif -b 1500 -html      : Take the difference of the last 2 snap period

          aw -cr_sql_profile <source sql_id> -s <target sql_id> -ph <plan_hash_value>  : Create a profile using given sql_sid an plan_hash_value
                                       this differ from -prf as you provide the set of outlines while -prf takes the one of the optimizer
          aw -prf  <sql_id>          : Generate sql_profile from <sql_id>
          aw -sgen <sql_id>          : sql text +  fetch & initialize binds from v\\$sql_bind_capture

          aw -ev -owc -cl "User I/O" -b 8150 -e 8155 : List event of type User I/O between the 2 snaps sort by class (owt : sort by time)
          aw -ev -name "control file parallel write" -b 8160 -e 8202  : list figures for given event for 43 consecutives snaps

          
EOF
exit
}
# ---------------------------------------------------------------------------
function get_snap_beg_end
{
    ret=`sqlplus -s "$CONNECT_STRING"  <<EOF
column instance_number   new_value instance_number  noprint
select instance_number from   v\\$instance ;
 set head off verify off feed off pause off 
col beg_id new_value beg_id 
col end_id new_value end_id 

select  beg_id,end_id from (
  select beg_id,end_id,rank() over (order by rownum ) rn from (
select  rownum, snap_id beg_id, lag(snap_id,1) over (order by begin_interval_time desc ) end_id
        from
            sys.wrm\\$_snapshot 
         where instance_number=&instance_number $AND_DBID
        order by begin_interval_time desc)) where rn=2;
EOF`
 echo "$ret" | sed '/^$/d' | tr -d '\n'
# the output of 2 rows is the return of this function
}
# ---------------------------------------------------------------------------
if [  -z "$1" ];then
   help
   exit
fi
typeset -u F_USER
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
TITTLE="All about AWR"
ROWNUM=50
EXECUTE=NO
AWR_OUTPUT_TYPE=text
REP_TYPE=DEFAULT
CATEGORY=DEFAULT

while [ -n "$1" ]
do
   case "$1" in
     -ad ) METHOD=AWR_ADV;;
    -ash ) METHOD=ASH  ;;
  -b|-b1 ) SNAP1=$2 ; shift ;;
     -b2 ) SNAP3=$2 ; shift ;;
    -bbw ) METHOD=BBW ; EXECUTE=YES ;;
    -rdl ) METHOD=REDO_LGW ; EXECUTE=YES 
           if [ -z "${2%%*[0-9]*}" ];then
              BACK_SNAP=$2 ; shift 
           fi
           ;;
    -cat ) CATEGORY=$2; shfit ;;
     -cl ) CLASS="$2" ; shift ;;
 -cr_prf ) CR_SQL_PROFILE=TRUE  ; SOURCE_SQL_ID=$2; shift;;
   -dbid ) DBID=$2; shift ;;
    -dif ) METHOD=AWR_DIF_REPORT; EXECUTE=YES;;
  -e|-e1 ) SNAP2=$2 ; shift ;;
     -e2 ) SNAP4=$2 ; shift ;;
   -each ) METHOD=AWR_SQL_LOAD_EACH ; EXECUTE=YES;;
    -enq ) METHOD=ENQUEUE  ; EXECUTE=YES ;;
     -se ) METHOD=LIST_EVENTS; FEVENT="$2" ; shift ; EXECUTE=YES ;;
     -ev ) METHOD=SYSTEM_EVENTS;  EXECUTE=YES ;;
    -evh ) METHOD=EVENTS_HISTOGRAM;  EXECUTE=YES ;;
      -f ) METHOD=LIST_SNAP_2 ; SQL_ID=$2 ; shift ;  EXECUTE=YES ;;
     -gn ) METHOD=GN ; MET_ID=$2 ; shift ; EXECUTE=YES ;;
      -h ) help; exit ;;
   -hist ) METHOD=TBL_HISTORY ; EXECUTE=YES;;
   -html ) AWR_OUTPUT_TYPE=html ;;
     -io ) METHOD=AW_FILE_IO ; EXECUTE=YES;;
     -io_load ) METHOD=IO_LOAD ; EXECUTE=YES;;
    -inst) INST_NUM=$2 ; SHOW_INST=TRUE; shift ;;
      -k ) METHOD=SHOW_KEEP_FTS ; EXECUTE=YES; TITTLE='full table scans and counts';;
      -l ) METHOD=LIST_SNAP; EXECUTE=YES ;;
     -lb ) METHOD=SHOW_BIND ; SQL_ID=$2; shift; EXECUTE=YES;;
    -lsm ) METHOD=LIST_LAST_METRIC; ROWNUM=50 ; EXECUTE=YES;;
    -lbs ) METHOD=LIST_BASELINE; EXECUTE=YES ;;
    -lbw ) METHOD=LBW ; EXECUTE=YES ;;
    -len ) LEN_TEXT=$2; shift ;;
   -lprf ) METHOD=LIST_ADV_PRF;
           if [ -n "$2" ];then
              SQL_PRF=$2; shift
           else 
              SQL_PRF=SQL_PRF
            fi
            EXECUTE=YES ;;
  -llprf ) METHOD=SHOW_TASK; TASK=$2; shift ;EXECUTE=YES ;;
   -lret ) METHOD=RET; EXECUTE=YES ;;
   -lsdb ) METHOD=LIST_DBID; EXECUTE=YES ;;
    -lsi ) METHOD=LSI; EXECUTE=YES ;;
    -lst ) METHOD=LST; EXECUTE=YES ;;
     -m  ) PROGRAM="program" ;;
    -met ) METHOD=MET; EXECUTE=YES ;;
   -name ) EVENT_NAME="$2" ; shift ;;
    -pga ) METHOD=PGASTAT ; EXECUTE=YES ;;
    -prf ) METHOD=AWR_SQL_PROFILE ; SQL_ID=$2; shift; EXECUTE=YES;;
     -ph ) V_PLAN_HASH_VALUE=$2; shift ;;
   -ptext) PTEXT=TRUE ;;
  -purge ) METHOD=PURGE ;;
    -pv  ) PLAN_HASH_VALUE=$2; shift ;;
  -dpurge ) METHOD=DPURGE ; DAYS=$2; shift  ;;
     -pf ) METHOD=STATS_SQL_HIST; SQL_ID=$2; shift ; EXECUTE=YES ;;
     -ot ) AW_OUTLINES=TRUE;;
      -r ) METHOD=AWR_REPORT; EXECUTE=YES;;
     -rn ) ROWNUM=$2; FROWNUM=$ROWNUM ; shift ;;
      -s ) METHOD=AWR_SQL_ID ; SQL_ID=$2; shift; EXECUTE=YES;;
     -sa ) METHOD=AWR_SESS1 ; SID=$2; shift; EXECUTE=YES;;
    -ser ) SERIAL=$2 ; shift ;;
    -set ) METHOD=SET
           if [ -n "$2" ];then
               DURATION=$2 
               shift
               if [ -n "$2" ];then
                   INT_MINUTES=$2
                   shift
               fi
           fi
           ;;
    -sid ) SID=$2 ; shift ;;
   -sgen ) METHOD=GEN_SQL_BIND; SQL_ID="$2"; shift ; EXECUTE=YES;;
     -sl ) METHOD=AWR_SQL_LOAD ; EXECUTE=YES;;
    -sll ) METHOD=AWR_SQL_LOAD ; LAST_SNAP=TRUE; EXECUTE=YES;;
    -sla ) METHOD=AWR_SESS_LCK ; ALL_SESS=TRUE;  EXECUTE=YES;;
    -slp ) METHOD=AWR_SESS_SIMPLE ; ALL_SESS=TRUE;  EXECUTE=YES;;
    -slp ) METHOD=AWR_SESS_SIMPLE ; ALL_SESS=TRUE;  LAST_P=TRUE; EXECUTE=YES;;
    -slk ) METHOD=AWR_SESS_LCK ; EXECUTE=YES;;
    -slc ) METHOD=AWR_SESS_COST ; EXECUTE=YES;;
     -st ) METHOD=AWR_SHOW_TEXT ; SQL_ID=$2 ; shift ; EXECUTE=YES ;;
     -so ) SO_SQL_ID=$2 ; shift ;;
    -sta ) STA_SQL_ID=$2 ; shift ;;
    -str ) METHOD=AWR_SEARCH_TEXT ; STR="%${2}%" ; shift ; EXECUTE=YES ;;
    -sts ) METHOD=AWR_STS ;  EXECUTE=YES ;;
      -t ) ftable=`echo $2 | awk '{ print toupper($0)}'` ; shift ;;
     -tb ) TBS=$2 ; shift ;;
     -tr ) METHOD=SQL_TUNE     ; SQL_ID="$2"; shift ; EXECUTE=YES ;;
 -tr_prf ) METHOD=TR_SQL_PROFILE  ;;
    -use ) METHOD=AWR_USE      ; EXECUTE=YES;;
     -xx ) METHOD=GET_SNAP     ; EXECUTE=YES;;
    -xpf ) METHOD=DIF_PLAN     ; EXECUTE=YES;;
     -pl ) METHOD=SHOW_PLAN ;  PLAN_HASH_VALUE=$2 ; shift   ; EXECUTE=YES;;
    -lpt ) METHOD=PLAN_OBJ ;  fobj=$2 ; shift   ; EXECUTE=YES;;
   -comp ) COMPACT=TRUE ;;
   -wait ) REP_TYPE=WAITS;;
  -reads ) REP_TYPE=DISK_READS;;
 -writes ) REP_TYPE=DISK_WRITES;;
   -exec ) REP_TYPE=EXECS;;
    -row ) REP_TYPE=ROWS;;
      -u ) OWNER=$2 ; shift ;;
    -owt ) ORDER_BY=WAIT_TIME ;;
    -owc ) ORDER_BY=WAIT_CLASS ;;
     -nh ) NO_HEADER=TRUE ;;
      -x ) EXECUTE=YES ;;
      -xn ) EXECUTE=NO ;;
      -v ) VERBOSE=TRUE ; set -x;;
       * ) echo "Invalid $1"; help ;;
   esac
   shift
done

# --------------------------------------------------------------------------

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
if [ -z "$DBID" ];then
    SHOW_INST=${SHOW_INST:-FALSE}
    ret=`sqlplus -s "$CONNECT_STRING"<<EOF
    set head off verify off pause off
         select dbid , i.instance_number from sys.v_\\$database d, sys.v_\\$instance i;
EOF`
    ret=`echo $ret| tr -d '\n'|tr -d '\r'`
    DBID=`echo "$ret" |awk '{print $1}'`
    if [ -z "$INST_NUM" ];then
       INST_NUM=`echo "$ret" |awk '{print $2}'`
    fi
else
   SHOW_INST=TRUE
fi
if [ "$SHOW_INST" = "TRUE" ];then
     F_INST_NUM="instance_number,"
fi
if [ -n "$DBID" ];then
   F_DBID=",dbid"
   DBID_F="dbid,"
   S_DBID="s.dbid,"
   AND_DBID=" and dbid= '$DBID'" 
   AND_S_DBID=" and s.dbid= '$DBID'" 
   AND_S0_DBID=" and s0.dbid= '$DBID'" 
   AND_A_DBID=" and a.dbid= '$DBID'" 
   AND_STAT_DBID=" and stat.dbid= '$DBID'" 
   INST_NUM=${INST_NUM:-1} # default
fi
AND_INST_NUM=" and instance_number=$INST_NUM"
AND_A_INST_NUM=" and a.instance_number=$INST_NUM"
# check that SQL_ID is not an hash_value, and if so convert it to SQL_ID
if [ -n "$SQL_ID" ];then
   SQL_ID=`get_sql_id $SQL_ID`
fi



# ...........................................................
#  List table size : table segment, index, lob
# ...........................................................
if [ "$METHOD" = "TBL_HISTORY" ];then

if [ -z "$ftable" ] ;then
     echo "I need a table name"
     exit 
fi
if [ -n "$ftable" -a -z "$fowner" ];then
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select  trim(to_char(count(*))) cpt from dba_tables where table_name='$ftable' ;
EOF`
  ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
if [ -z "$ret" ];then
  echo "Currently, there is no entry in dba_tables for $ftable"
  exit
elif [ "$ret" -eq "0" ];then
  echo "Currently, there is no entry in dba_tables for $ftable"
  exit
elif [ "$ret" -eq "1" ];then
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select owner from dba_tables where  TABLE_NAME='$ftable' and rownum=1 ;
EOF`
     fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
     FOWNER="owner = '$fowner' "
     AND_FOWNER=" and  $FOWNER"
     A_FOWNER=" a.owner = '$fowner'"
elif [ "$ret" -gt "0"  ];then
   if [ -z "$fowner" ];then
    echo " there are many tables for $ftable:"
    echo " Use : "
    echo
    echo " aw -hist -t $ftable -u <user> "
    echo
 sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on
select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
EOF
    exit
   fi
fi
fi

# ...............................................................
# 2016-06-09 Found this query at : https://weidongzhou.wordpress.com/
# ...............................................................

     sqlplus -s "$CONNECT_STRING"  <<EOF
col owner for a12
col object_name for a25
col object_type for a15
col subobject_name for a25
col obj# for 999999
col save_time for a20
col analyze_time for a20
set lines 190 pages 66
select o.owner, o.object_name, o.subobject_name, th.obj#, o.object_type,
to_char(analyzetime, 'yyyy-mm-dd hh24:mi:ss') analyze_time,
rowcnt, blkcnt, avgrln, samplesize, samplesize,
to_char(savtime, 'yyyy-mm-dd hh24:mi:ss') save_time
from sys.WRI\$_OPTSTAT_TAB_HISTORY th,
dba_objects o
where
o.object_id = th.obj#
and o.owner = '$fowner'
and o.object_name = '$ftable'
order by th.analyzetime desc
/

EOF

# --------------------------------------------------------------------------
# AWR List last DB metrics
# --------------------------------------------------------------------------
# Found on "http://karlarao.wordpress.com/scripts-resources/"
# a script from Karl Arao.
# Adapted to Smenu by bpa : I am not convinced on the real usage of these info.
# For you usually don't know how the SAN raid is implemented. The figures here
# may be completely misleading
#
elif [ "$METHOD" = "AW_FILE_IO" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi

  if [ -n "$TBS" ];then
        AND_TBS=" and e.tsname = upper('$TBS') "
  fi
TITTLE="General DB operations stats"
SQL="
set lines 190
col snap_id     format 99999            heading 'Snap|ID'
col inst        format 90               heading 'i|n|s|t|#'
col dur         format 999990.00        heading 'Snap|Dur|(m)'
col tsname      format a30              heading 'TS'
col file#       format 9990             heading 'File#'
col filename    format a60              heading 'Filename'
col io_rank     format 90               heading 'IO|Rank'
col readtim     format 9999999          heading 'Read|Time'
col reads       format 9999999          heading 'Reads'
col atpr        format 99990.0          heading 'Av|Rd(ms)'
col rps         format 9999999          heading 'IOPS|Av|Reads/s'
col bpr         format 99990.0          heading 'Av|Blks/Rd'
col writetim    format 9999999          heading 'Write|Time'
col writes      format 9999999          heading 'Writes'
col atpw        format 99990.0          heading 'Av|Wt(ms)'
col wps         format 9999999          heading 'IOPS|Av|Writes/s'
col bpw         format 99990.0          heading 'Av|Blks/Wrt'
col waits       format 9999999          heading 'Buffer|Waits'
col atpwt       format 99990.0          heading 'Av Buf|Wt(ms)'
col ios         format 9999999          heading 'Total|IO R+W'
col iops        format 9999999          heading 'IOPS|Total|R+W'
break on snap_id on report
select snap_id , tsname, file#
  , io_rank, readtim, reads, atpr, rps, bpr, writetim, writes, atpw
   , wps, bpw , waits, atpwt
from
      (select snap_id,  inst,  tsname, file#, readtim, reads, atpr, rps, bpr,
              writetim, writes, atpw, wps, bpw, waits, atpwt, ios, iops,
               DENSE_RANK() OVER ( PARTITION BY snap_id ORDER BY ios DESC) io_rank
      from
              (
                select
                     s0.snap_id snap_id,  s0.instance_number inst, e.tsname,
                      e.file# , e.readtim  - nvl(b.readtim,0) readtim , e.phyrds - nvl(b.phyrds,0) reads
                      , decode ((e.phyrds - nvl(b.phyrds, 0)), 0, to_number(NULL),
                                ((e.readtim  - nvl(b.readtim,0)) / (e.phyrds   - nvl(b.phyrds,0)))*10) atpr
                      , (e.phyrds - nvl(b.phyrds,0)) /
                          ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                          + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                          + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                          + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) rps      -- ela
                          , decode ((e.phyrds - nvl(b.phyrds, 0)), 0, to_number(NULL),
                              (e.phyblkrd - nvl(b.phyblkrd,0)) / (e.phyrds   - nvl(b.phyrds,0)) ) bpr
                          , e.writetim  - nvl(b.writetim,0)                 writetim
                          , e.phywrts - nvl(b.phywrts,0)                    writes
                          , decode ((e.phywrts - nvl(b.phywrts, 0)), 0, to_number(NULL),
                               ((e.writetim  - nvl(b.writetim,0)) / (e.phywrts   - nvl(b.phywrts,0)))*10) atpw
                          , (e.phywrts - nvl(b.phywrts,0)) /
                               ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                               + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                               + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                               + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) wps      -- ela
                          , decode ((e.phywrts - nvl(b.phywrts, 0)), 0, to_number(NULL),
                                  (e.phyblkwrt - nvl(b.phyblkwrt,0)) / (e.phywrts   - nvl(b.phywrts,0)) ) bpw
                          , e.wait_count - nvl(b.wait_count,0)  waits
                          , decode ((e.wait_count - nvl(b.wait_count, 0)), 0, 0, ((e.time - nvl(b.time,0))
                                       / (e.wait_count - nvl(b.wait_count,0)))*10)   atpwt
                          , (e.phyrds  - nvl(b.phyrds,0)) + (e.phywrts - nvl(b.phywrts,0))                     ios
                          , ((e.phyrds  - nvl(b.phyrds,0)) + (e.phywrts - nvl(b.phywrts,0))) /
                                            ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                                            + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                                            + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                                            + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) iops
                   from
                        dba_hist_snapshot s0,
                        dba_hist_snapshot s1,
                        dba_hist_filestatxs e,
                        dba_hist_filestatxs b
                    where s0.snap_id >= $SNAP1 and s0.snap_id < $SNAP2 $AND_S0_DBID $AND_TBS
                      and s1.dbid               = s0.dbid
                      and b.dbid(+)             = s0.dbid           -- begin dbid
                      and e.dbid                = s0.dbid           -- end dbid
                      and b.dbid                = e.dbid -- remove oj
                      AND s0.instance_number    = $INST_NUM  -- CHANGE THE INSTANCE_NUMBER HERE!
                      AND s1.instance_number    = s0.instance_number
                      and b.instance_number(+) = s0.instance_number  -- begin instance_num
                      and e.instance_number    = s0.instance_number  -- end instance_num
                      and b.instance_number    = e.instance_number      -- remove oj
                      and s1.snap_id           = s0.snap_id + 1
                      and b.snap_id(+)         = s0.snap_id          -- begin snap_id
                      and e.snap_id            = s0.snap_id + 1      -- end snap_id
                      and b.tsname             = e.tsname -- remove oj
                      and b.file#              = e.file# -- remove oj
                      and b.creation_change# = e.creation_change# -- remove oj
                      and ((e.phyrds  - nvl(b.phyrds,0))  +
                           (e.phywrts - nvl(b.phywrts,0))) > 0
            union all
                 select
                     s0.snap_id snap_id, s0.instance_number inst,
                     e.tsname, e.file# , e.readtim  - nvl(b.readtim,0) readtim , e.phyrds- nvl(b.phyrds,0)   reads
                     , decode ((e.phyrds - nvl(b.phyrds, 0)), 0, to_number(NULL),
                               ((e.readtim  - nvl(b.readtim,0)) / (e.phyrds   - nvl(b.phyrds,0)))*10)         atpr
                     , (e.phyrds- nvl(b.phyrds,0)) /
                           ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                           + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                           + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                           + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) rps       -- ela
                     , decode ((e.phyrds - nvl(b.phyrds, 0)), 0, to_number(NULL),
                            (e.phyblkrd - nvl(b.phyblkrd,0)) / (e.phyrds   - nvl(b.phyrds,0)) )             bpr
                     , e.writetim  - nvl(b.writetim,0)                 writetim
                     , e.phywrts - nvl(b.phywrts,0)                    writes
                     , decode ((e.phywrts - nvl(b.phywrts, 0)), 0, to_number(NULL),
                             ((e.writetim  - nvl(b.writetim,0)) / (e.phywrts   - nvl(b.phywrts,0)))*10)         atpw
                     , (e.phywrts - nvl(b.phywrts,0)) /
                           ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                           + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                           + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                           + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) wps        -- ela
                     , decode ((e.phywrts - nvl(b.phywrts, 0)), 0, to_number(NULL),
                            (e.phyblkwrt - nvl(b.phyblkwrt,0)) / (e.phywrts   - nvl(b.phywrts,0)) )             bpw
                    , e.wait_count - nvl(b.wait_count,0)              waits
                    , decode ((e.wait_count - nvl(b.wait_count, 0)), 0, to_number(NULL),
                          ((e.time       - nvl(b.time,0)) / (e.wait_count - nvl(b.wait_count,0)))*10)   atpwt,
                          (e.phyrds  - nvl(b.phyrds,0)) + (e.phywrts - nvl(b.phywrts,0))                     ios
                    , ((e.phyrds  - nvl(b.phyrds,0)) + (e.phywrts - nvl(b.phywrts,0))) /
                          ((round(EXTRACT(DAY FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 1440
                          + EXTRACT(HOUR FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) * 60
                          + EXTRACT(MINUTE FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME)
                          + EXTRACT(SECOND FROM s1.END_INTERVAL_TIME - s0.END_INTERVAL_TIME) / 60, 2))*60) iops
                   from
                        dba_hist_snapshot s0,
                        dba_hist_snapshot s1,
                        dba_hist_tempstatxs e,
                        dba_hist_tempstatxs b
                    where s0.snap_id >= $SNAP1 and s0.snap_id < $SNAP2 $AND_S0_DBID $AND_TBS
                        AND s1.dbid               = s0.dbid
                        and b.dbid(+)             = s0.dbid                               -- begin dbid
                        and e.dbid                = s0.dbid                               -- end dbid
                        and b.dbid                = e.dbid -- remove oj
                        AND s0.instance_number    = $INST_NUM
                        AND s1.instance_number    = s0.instance_number
                        and b.instance_number(+)  = s0.instance_number                                        -- begin instance_num
                        and e.instance_number     = s0.instance_number                                        -- end instance_num
                        and b.instance_number     = e.instance_number -- remove oj
                        AND s1.snap_id            = s0.snap_id + 1
                        and b.snap_id(+)          = s0.snap_id                                      -- begin snap_id
                        and e.snap_id             = s0.snap_id + 1                                      -- end snap_id
                        and b.tsname              = e.tsname -- remove oj
                        and b.file#               = e.file# -- remove oj
                        and b.creation_change#    = e.creation_change# -- remove oj
                        and ((e.phyrds  - nvl(b.phyrds,0))  + (e.phywrts - nvl(b.phywrts,0))) > 0
              )
      ) order by snap_id desc
/
"
# --------------------------------------------------------------------------
elif [ "$METHOD" = "IO_LOAD" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi

SQL="
set lines 250
set pages 9999
col Physical_Read_Total_Bps head 'Tot reads| Meg/second' 
col  head 'Tot reads| Meg/second' 
col Physical_Read_Total_Bps head 'Tot reads| Meg/second' 
col Physical_Write_Total_Bps head 'Tot Writes| Meg/second' 
col Redo_Bytes_per_sec head 'Tot redo | Meg/second' 
col Physical_Read_IOPS head 'IO | reads/second' 
col Physical_write_IOPS head 'IO| Write/second' 
col Physical_redo_IOPS head 'Tot redo | IOPS/second' 
col OS_LOad head 'OS load reads' 
col DB_CPU_Usage_per_sec head 'CB CPU| per second' 
col user_commits head 'User| commits'
col user_transactions head 'User| transactions'
col Host_CPU_util head 'CPU % ' 
col Network_bytes_per_sec head 'Network | Meg/second' 
select        snap_id, to_char(min(begin_time),'YYYY-MM-DD HH24:MI') begin_time, to_char(max(end_time),'HH24:MI') end_time,
       round(sum(case metric_name when 'Physical Read Total Bytes Per Sec' then average end)/1024/1024,2) Physical_Read_Total_Bps,
       round(sum(case metric_name when 'Physical Write Total Bytes Per Sec' then average end)/1024/1024,2) Physical_Write_Total_Bps,
       round(sum(case metric_name when 'Redo Generated Per Sec' then average end)/1024/1024,2) Redo_Bytes_per_sec,
       round(sum(case metric_name when 'User Commits Per Sec' then average end)/1024/1024,2) user_commits,
       round(sum(case metric_name when 'Redo Generated Per Sec' then average end)/1024/1024,2) user_transactions,
       round(sum(case metric_name when 'Current OS Load' then average end),2) OS_LOad,
       round(sum(case metric_name when 'CPU Usage Per Sec' then average end),2) DB_CPU_Usage_per_sec, 
       round(sum(case metric_name when 'Host CPU Utilization (%)' then average end),2) Host_CPU_util, 
       round(sum(case metric_name when 'Network Traffic Volume Per Sec' then average end)/1024/1024,2) Network_bytes_per_sec
from dba_hist_sysmetric_summary
where 
    snap_id >= $SNAP1 and snap_id < $SNAP2 
group by snap_id
order by snap_id desc
/
"
       #--round(sum(case metric_name when 'Physical Read Total IO Requests Per Sec' then average end)/1024/1024,2) Physical_Read_IOPS,
       #--round(sum(case metric_name when 'Physical Write Total IO Requests Per Sec' then average end)/1024/1024,2) Physical_write_IOPS,
      # --round(sum(case metric_name when 'Redo Writes Per Sec' then average end)/1024/1024,2) Physical_redo_IOPS,
# --------------------------------------------------------------------------
# instance-level statistics variations
# found at : https://savvinov.com/2016/12/23/dealing-with-a-global-increase-in-cpu-usage/#more-4571
# Author : savvinov, 23-Dec-2016
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_STS" ];then
SQL="
with a as
(
  select begin_interval_time t, stat_name, value
  from dba_hist_snapshot sn,
       dba_hist_sysstat ss
  where sn.snap_id = ss.snap_id
  and sn.instance_number = 1
  and ss.instance_number = 1
),
b as
(
  select t, t - trunc(t, 'day') time_within_week,  to_char(t, 'ww') week_number, stat_name, value - lag(value) over (partition by stat_name order by t) value
  from a
),
c as
(
  select t, stat_name, trunc(t, 'day') beginning_of_week, time_within_week, value, week_number
  from b
  where time_within_week < systimestamp - trunc(systimestamp, 'day')   and value >= 0
),
d as
(
  select stat_name, week_number, row_number() over (partition by stat_name order by week_number desc) rn, /*rn, */avg(value) value
  from c
  group by stat_name, week_number--, rn
  order by week_number, stat_name
),
f as
(
  select stat_name, avg(value) average_value, stddev(value) stddev_value
  from d
  where rn > 1
  group by stat_name
  order by stat_name
),
g as
(
  select this_week.stat_name, this_week.value current_week_value, prev_weeks.average_value prev_average, prev_weeks.stddev_value prev_stddev
  from f prev_weeks,
       d this_week
  where this_week.rn = 1
  and this_week.stat_name = prev_weeks.stat_name
  and this_week.value > 1000
),
h as
(
  select stat_name,
         trunc(current_week_value) current_week_value,
         trunc(prev_average) prev_weeks_value,
         trunc((current_week_value-prev_average)*100/nullif(prev_average,0)) change_pct,
         trunc(100*prev_stddev/nullif(prev_average,0)) sigma
  from g
)
select *
from h
where abs(change_pct) >= 3*sigma
order by change_pct desc nulls last
/
"
# --------------------------------------------------------------------------
# AWR List last DB metrics
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_LAST_METRIC" ];then

  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d' '`
     SNAP1=`expr $VVAR - $ROWNUM`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi

TITTLE="General DB operations stats"
SQL="
set lines 210
col snap_id for 999999 head 'Snap|id' justify c
col tgets        format    99999990  heading 'Gets(s)' justify c
col tdbch        format    99999990  heading 'Db block|Changes(s)' justify c
col trds         format    99999990  heading 'Physical|Read(s)' justify c
col trdds        format    99999990  heading 'Physical|direct|Read(s)' justify c
col twrs         format    99999990  heading 'Physical|write(s)' justify c
col twrds         format    99999990  heading 'Direct|write(s)' justify c
col texecs       format    999999990  heading 'Execute|Count(s)' justify c
col ttslt        format    999990  heading 'Table| scans(s)' justify c
col tiffs        format    999990  heading 'Index fast|full scans(s)' justify c
col tucms         format    999990  heading 'Commits|second' justify c
col tur          format    99990  heading 'User|Rollbacks' justify c
col db_time format  999990 head 'Db time|(s)'
col cpu_time format 999990 head 'CPU time|(s)'
col snap_begin head 'Date' justify c


select snap_id, snap_begin, snap_len,
      round(max(case when stat_name = 'execute count'
                then (value - lag_value) /decode(snap_len,0,1,snap_len)
                else 0
            end),0) texecs
     ,round(max(case when stat_name = 'session logical reads'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) tgets
     , round(max(case when stat_name = 'db block changes'
                then ( value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) tdbch
     , round(max(case when stat_name = 'physical reads' -- physical reads cache?
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) trds
     , round(max(case when stat_name = 'physical reads direct'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) trdds
     , round(max(case when stat_name = 'physical writes' -- physical reads cache?
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) twrs
     , round(max(case when stat_name = 'physical writes direct'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) twrds
     , round(max(case when stat_name = 'table scans (long tables)'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) ttslt
     , round(max(case when stat_name = 'index fast full scans (full)'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) tiffs
     , round(max(case when stat_name = 'user commits'
                then value - lag_value
                else 0
            end)/decode(snap_len,0,1,snap_len),1) tucms
     , round(max(case when stat_name = 'user rollbacks'
                then value - lag_value
                else 0
            end),0) tur
     , round(max(case when stat_name = 'DB time'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) Db_time
     , round(max(case when stat_name = 'CPU used by this session'
                then (value - lag_value)/decode(snap_len,0,1,snap_len)
                else 0
            end),0) cpu_time
from (
     select a.snap_id, to_char(BEGIN_INTERVAL_TIME,' dd-Mon HH24:mi:ss')    snap_begin, 
   round( extract( day from s.END_INTERVAL_TIME - s.BEGIN_INTERVAL_TIME) *24*60*60*60+
                    extract( hour from s.END_INTERVAL_TIME - s.BEGIN_INTERVAL_TIME) *60*60+
                    extract( minute from s.END_INTERVAL_TIME - s.BEGIN_INTERVAL_TIME )* 60 +
                    extract( second from s.END_INTERVAL_TIME - s.BEGIN_INTERVAL_TIME )) snap_len ,
      stat_name, value, lag(value) over (partition by stat_name order by a.snap_id) lag_value
     from dba_hist_sysstat a, sys.wrm\$_snapshot s
     where s.snap_id = a.snap_id and s.dbid = a.dbid and
           a.snap_id  >=  $SNAP1-1 and a.snap_id <= $SNAP2 $AND_A_DBID $AND_A_INST_NUM
           and stat_name in (
               'db block gets','DB time','CPU used by this session',
               'session logical reads', 'db block changes'
               , 'physical reads', 'physical reads direct'
               , 'physical writes', 'physical writes direct'
               , 'execute count'
               , 'index fast full scans (full)' , 'table scan (long tables)'
               , 'user commits', 'user rollbacks' )
order by stat_name, a.snap_id ) 
where snap_id >= $SNAP1 and snap_id <= $SNAP2
group by snap_id, snap_begin, snap_len order by snap_id desc
/
"
# --------------------------------------------------------------------------
# AWR search text
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SEARCH_TEXT" ];then
FLEN=${FLEN:-80}
if [ -n  "$SNAP1" ];then
   if [ -z "$SNAP2" ];then
       echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
       SNAP2=`expr $SNAP1 + 1`
       echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
fi
SQL="
set linesize 190 pages 66  head on
col sql_text for a${FLEN} head 'Sql Text'
select /*+ comment */ snap_id,sql_id, substr(sql_text,1,$FLEN) sql_text
      from  sys.WRH\$_SQLTEXT
      where  upper(sql_text) like upper('${STR}') $AND_DBID $AND_SNAP
      order by snap_id desc
/
"
# --------------------------------------------------------------------------
# List DBID present in the repository
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SESS1" ];then
  if [ -n "$SERIAL" ];then
       AND_SERIAL=" and session_serial# = $SERIAL"
  fi
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  #AND_SNAP1=" and snap_id = '$SNAP1' "
  AND_SNAP1=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  if [  "$PTEXT" = "TRUE" ];then
       SHOW_FIELDS=",CURRENT_OBJ# obj#,CURRENT_FILE# f#, CURRENT_BLOCK# b#,p1text||':' || to_char(p1) p1 ,p2text||':'||to_char(p2) p2, p3text||':'||to_char(p3) p3"
  else 
       SHOW_FIELDS=", wait_class,event,blocking_session, blocking_session_serial# bser"
  fi
SQL="
col SESSION_ID head 'Sid' format 99999
col serial# for 99999 head 'Serl#'
col time_waited format 9999990.9 head 'Time|wait(s)'
col BLOCKING_SESSION forma 999999 head 'Block|sess' justify c
col bser for 99999 head 'Block|sess|serl#'
col event head 'Event' format a29
col p1 for a20  wrapped
col p2 for a20  wrapped
col p3 for a20  wrapped
col user_id head 'Usr|id' format 999
col f# for 999
col b# for 9999999
col wait_class for a12 head 'Wait class'
col username for a12 head 'Username'
col sample_time head 'Sample|time'
col instance_number for 999 head 'Inst|Num'
col wait_time for 9990.00 head 'Prev|wait| time(s)' justify c
col program head 'Program' for a26
col machine head 'Machine' for a12
col module head 'module' for a26
col SQL_PLAN_OPERATION head 'SQL Plan|operation' for a16
set lines 210 trimspool on
break on username on user_id on serial# on sql_id on report
 with v1 as (select distinct parsing_schema_id user_id, parsing_schema_name  
                 username from SYS.DBA_HIST_SQLSTAT 
             where 1=1 $AND_DBID $AND_SNAP1)
select   session_id, to_char(sample_time,'HH24:MI:SS') sample_time,
               username, a.user_id , instance_number, program, machine, module,
               session_serial# serial#, wait_time/100 wait_time, sql_id,  SQL_PLAN_OPERATION $SHOW_FIELDS
from
                 DBA_HIST_ACTIVE_SESS_HISTORY a, v1 b
               where  b.user_id = a.user_id and
                 1=1 and session_id = '$SID' $AND_SERIAL $AND_SNAP1 $AND_DBID
order by  sample_time,session_serial#
/
"
# --------------------------------------------------------------------------
# List Session activity for given SNAP and cost at that time
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SESS_COST" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
     AND_SNAP1=" and a.snap_id > $SNAP1 and a.snap_id <= $SNAP2 "
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     AND_SNAP1=" and a.snap_id >= $SNAP1 and a.snap_id < $SNAP2 "
     echo "Using default -b <nn> + 1> --> $SNAP2"
  else
      AND_SNAP1=" and a.snap_id >= $SNAP1 and a.snap_id <= $SNAP2 "
  fi
  if [ -n "$SID" ];then
     AND_SID=" and a.session_id = '$SID' "
  fi
LEN_TEXT=${LEN_TEXT:-35}
FROWNUM=${FROWNUM:-50000}
TITTLE="Processing only first $FROWNUM rows of snap range, use -rn <nn> to increase input sample"
SQL="
col user_id head 'Usr|id' format 999
col event head 'Event' format a28
col usr_sqlid format a35
col fsid for a14 head 'Sid'
col sid_sql for a${LEN_TEXT} head 'Session sql text' 
col bser for 99999 head 'Block|sess|serl#'
col ser for 99999 head 'Serl#'
col cost for 999999 head 'This|Snap|Cost' justify c
col gets for 99999999 head 'This|Snap|gets/exc' justify c
col elapsed for 9999990.0 head 'This|Snap|Elsap|sed(cs)' justify c
col avg_cost for 999999 head 'Avg|Snap|Cost' justify c
col avg_elapsed for 9999990.0 head 'Avg|Snap|Elsap|sed(cs)' justify c
set long 32000
col sample_time for a8 head 'Time'
break on instance_number on sample_time on report
col wait_time for 9990.00 head 'Prev |wait| time(s)' justify c
col program for a26 head 'Program' justify c
set wrap off
set lines 190

prompt  Prev wait : any value > 0 means SQL currently running on CPU, numeric refer to wait(secs) before this run
prompt 
select instance_number, to_char(sample_time,'HH24:MI:SS')sample_time, lpad(' ',level*2) ||  session_id fsid, 
    ser, program, user_id,a.sql_id, decode(wait_time,0,' -wait-', to_char(wait_time,'99990.00')) wait_time, 
    cost, avg_cost,elapsed, gets, SQL_PLAN_HASH_VALUE,
      substr(t.sql_text,1,${LEN_TEXT}) sid_sql
from
 (
  select * from (
     select distinct
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.session_id)||'.'||to_char(a.SESSION_SERIAL#) sid,
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.blocking_session)||'.'||to_char(a.blocking_SESSION_SERIAL#) bsid,
        a.session_id, a.session_serial# ser,  a.instance_number, a.user_id,
        a.sql_id, a.event, a.sample_time,   a.wait_time/100 wait_time, b.OPTIMIZER_COST cost, b.ELAPSED_TIME_DELTA/10000 elapsed,
        c.COST avg_cost, b.BUFFER_GETS_DELTA/decode(EXECUTIONS_DELTA,0,1,EXECUTIONS_DELTA) getS, a.program, SQL_PLAN_HASH_VALUE
       from
           DBA_HIST_ACTIVE_SESS_HISTORY a, DBA_HIST_SQLSTAT b , DBA_HIST_SQL_PLAN c
      where 
            a.sql_id = b.sql_id and a.snap_id = b.snap_id 
        and a.instance_number = b.instance_number $AND_SNAP1 $AND_A_DBID
        and a.dbid = b.dbid 
        and  a.SQL_PLAN_HASH_VALUE = b.plan_hash_value
        and a.sql_id = c.sql_id  and a.dbid = c.dbid  and a.SQL_PLAN_HASH_VALUE = c.plan_hash_value and c.id=0
      order by
           a.sample_time, a.session_id, a.session_serial#
   )   where rownum <$FROWNUM
  )a,  
  dba_hist_sqltext t
where 
  t.sql_id (+) = a.sql_id 
connect by nocycle prior bsid = sid
/
"
# --------------------------------------------------------------------------
# List session SIMPLR
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SESS_SIMPLE" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f1 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
     AND_SNAP1=" and snap_id > $SNAP1 and snap_id <= $SNAP2"
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     AND_SNAP1=" and snap_id >= $SNAP1 and snap_id < $SNAP2"
     echo "Using default -b <nn> + 1> --> $SNAP2"
  else
     AND_SNAP1=" and snap_id >= $SNAP1 and snap_id <= $SNAP2"
  fi
  if [ -n "$SID" ];then
     AND_SID=" and a.session_id = '$SID' "
  fi
TITTLE="Processing only first $FROWNUM rows of snap range, use -rn <nn> to increase input sample"
LEN_TEXT=${LEN_TEXT:-35}
FROWNUM=${FROWNUM:-50000}
SQL="
set line 190 pages 80
col user_id head 'Usr|id' format 999
col event head 'Event' format a30
col usr_sqlid format a35
col fsid for a14 head 'Sid'
col sid_sql for a${LEN_TEXT} head 'Session sql text'
col bser for 99999 head 'Block|sess|serl#'
col ser for 99999 head 'Serl#'
col file# for 999 head 'Fl#'
col block# for 9999999 head 'block#'
col obj# for 99999999 head 'obj#'
col SQL_PLAN_HASH_VALUE  for 9999999999 head 'plan hv'
col sample_time for a8 head 'Time'
break on instance_number on sample_time on report
col wait_time for 9990.00 head 'Prev |wait| time(s)' justify c
col program head 'Program' justify c for a20
col PQ format a2 head 'Pq'
set wrap off

prompt  Prev wait : any value > 0 means SQL currently running on CPU, numeric refer to wait(secs) before this run
prompt
select instance_number, to_char(sample_time,'HH24:MI:SS')sample_time,  session_id sid,
    ser $ALT_FIELD, user_id,a.sql_id, decode(wait_time,0,' -wait-', to_char(wait_time,'99990.00')) wait_time,
    event  , file#, obj#, block# , SQL_PLAN_HASH_VALUE
     , substr(t.sql_text,1,${LEN_TEXT}) sid_sql
from
 (
  select * from (
     select distinct
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.session_id)||'.'||to_char(a.SESSION_SERIAL#) sid,
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.blocking_session)||'.'||to_char(a.blocking_SESSION_SERIAL#) bsid,
        session_id, session_serial# ser,  instance_number, user_id,
        sql_id,  decode(QC_SESSION_ID,null,'N','Y')PQ , event, sample_time,  CURRENT_OBJ# obj#, CURRENT_FILE# file#, CURRENT_BLOCK# block#,  wait_time/100 wait_time, 
        a.program , SQL_PLAN_HASH_VALUE
       from
           DBA_HIST_ACTIVE_SESS_HISTORY a
      where 1=1 $AND_SNAP1 $AND_DBID
      order by
           a.sample_time, a.session_id, a.session_serial#
   )    where rownum <$FROWNUM
  )a
   , dba_hist_sqltext t
 where t.sql_id (+) = a.sql_id
 order by a.sample_time
/
"
# --------------------------------------------------------------------------
# List session locking tree
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SESS_LCK" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f1 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
     AND_SNAP1=" and snap_id > $SNAP1 and snap_id <= $SNAP2"
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     AND_SNAP1=" and snap_id >= $SNAP1 and snap_id < $SNAP2"
     echo "Using default -b <nn> + 1> --> $SNAP2"
  else
     AND_SNAP1=" and snap_id >= $SNAP1 and snap_id <= $SNAP2"
  fi
  if [ -n "$SID" ];then
     AND_SID=" and a.session_id = '$SID' "
  fi
TITTLE="Processing only first $FROWNUM rows of snap range, use -rn <nn> to increase input sample"
LEN_TEXT=${LEN_TEXT:-35}
FROWNUM=${FROWNUM:-50000}
  if [ -n "$PROGRAM" ];then
        ALT_FIELD=",program"
  else
        unset ALT_FIELD
  fi
  if [ "$ALL_SESS" = "TRUE" ];then
        unset AND_ISLEAF
SQL="

set line 190 pages 80
col user_id head 'Usr|id' format 999
col event head 'Event' format a30
col usr_sqlid format a35
col fsid for a14 head 'Sid'
col sid_sql for a${LEN_TEXT} head 'Session sql text'
col bser for 99999 head 'Block|sess|serl#'
col ser for 99999 head 'Serl#'
col file# for 999 head 'Fl#'
col block# for 9999999 head 'block#'
col obj# for 99999999 head 'obj#'
col sample_time for a8 head 'Time'
break on instance_number on sample_time on report
col wait_time for 9990.00 head 'Prev |wait| time(s)' justify c
col program head 'Program' justify c for a20
col PQ format a2 head 'Pq'
set wrap off

prompt  Prev wait : any value > 0 means SQL currently running on CPU, numeric refer to wait(secs) before this run
prompt
select instance_number, to_char(sample_time,'HH24:MI:SS')sample_time, lpad(' ',level*2) ||  session_id fsid,
    ser $ALT_FIELD, user_id,a.sql_id, decode(wait_time,0,' -wait-', to_char(wait_time,'99990.00')) wait_time,
    event  , file#, obj#, block#, substr(t.sql_text,1,${LEN_TEXT}) sid_sql
from
 (
  select * from (
     select distinct
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.session_id)||'.'||to_char(a.SESSION_SERIAL#) sid,
        to_char(a.sample_time,'HH24:MI:SS') ||'.'||to_char(a.blocking_session)||'.'||to_char(a.blocking_SESSION_SERIAL#) bsid,
        session_id, session_serial# ser,  instance_number, user_id,
        sql_id,  decode(QC_SESSION_ID,null,'N','Y')PQ , event, sample_time,  CURRENT_OBJ# obj#, CURRENT_FILE# file#, CURRENT_BLOCK# block#,  wait_time/100 wait_time, 
        a.program
       from
           DBA_HIST_ACTIVE_SESS_HISTORY a
      where 1=1 $AND_SNAP1 $AND_DBID
      order by
           a.sample_time, a.session_id, a.session_serial#
   )    where rownum <$FROWNUM
  )a,
  dba_hist_sqltext t
where
  t.sql_id (+) = a.sql_id $AND_ISLEAF
connect by nocycle prior bsid = sid
order by a.sample_time
/
"
  else
SQL="
set lines 190 pages 82
col user_id head 'Usr|id' format 999
col event head 'Event' format a30
col usr_sqlid format a35
col fsid for a14 head 'Sid'
col sid_sql for a${LEN_TEXT} head 'Session sql text'
col bser for 99999 head 'Block|sess|serl#'
col ser for 99999 head 'Serl#'
col file# for 999 head 'Fl#'
col block# for 9999999 head 'block#'
col obj# for 99999999 head 'obj#'
col sample_time for a8 head 'Time'
break on instance_number on sample_time on report
col wait_time for 9990.00 head 'Prev |wait| time(s)' justify c
col program head 'Program' justify c for a26
set wrap off

prompt  Prev wait : any value > 0 means SQL currently running on CPU, numeric refer to wait(secs) before this run
prompt

with fview as (
    select
           blocking_session as session_id, blocking_SESSION_SERIAL# as SESSION_SERIAL# ,
           -1 as blocking_session, -1 as blocking_SESSION_SERIAL#,
           null sql_id,  decode(QC_SESSION_ID,null,'N','Y')PQ , null event , sample_time, null obj# , null file# ,
           null block# ,  null wait_time, null user_id, null  instance_number, program
    from DBA_HIST_ACTIVE_SESS_HISTORY a
         where  1=1 $AND_SNAP1 $AND_DBID  and blocking_session is not null
            and not exists (select null
                                   from DBA_HIST_ACTIVE_SESS_HISTORY
                             where
                                    session_id=a.blocking_session
                              and   session_serial#=a.blocking_session_serial# $AND_SNAP1 $AND_DBID
                              and   snap_id=a.snap_id
                              and   dbid=a.dbid
          )
   union
   select
         session_id, SESSION_SERIAL#, blocking_session, blocking_session_serial#,
         sql_id,  decode(QC_SESSION_ID,null,'N','Y')PQ , event, sample_time,  CURRENT_OBJ# obj#, CURRENT_FILE# file#,
         CURRENT_BLOCK# block#,  wait_time/100 wait_time, user_id, instance_number, program
   from DBA_HIST_ACTIVE_SESS_HISTORY a
        where 1=1 $AND_SNAP1 $AND_DBID
   )
select
       a.instance_number, to_char(a.sample_time,'HH24:MI:SS') sample_time,
       lpad(' ', 2*level)||session_id  fsid, PQ,
       SESSION_SERIAL# ser $ALT_FIELD, user_id, a.sql_id,
       decode(a.wait_time,0,' -wait-', to_char(wait_time,'99990.00')) wait_time,
       event  , a.file#, a.obj#, block#, substr(t.sql_text,1,$LEN_TEXT) sid_sql --,  blocking_session
from   ( select
                  instance_number, sample_time,
                  session_id, SESSION_SERIAL# , sql_id, PQ, event,  obj#, file#, block#,
                  wait_time, user_id, blocking_session, blocking_SESSION_SERIAL#, program
           from fview a
           start with not exists (select 1
                                  from
                                     fview b
                                  where
                                          b.sample_time            = a.sample_time
                                     and  b.blocking_session       = a.session_id
                                     and  blocking_session_serial# = a.SESSION_SERIAL# )
          connect by nocycle prior  sample_time              = sample_time
                      and   prior  blocking_session         = session_id
                      and   prior  blocking_SESSION_SERIAL# = SESSION_SERIAL#
          )a,
          dba_hist_sqltext t
    where
          t.sql_id (+) = a.sql_id
          connect by nocycle
                            prior session_id = blocking_session
                          and   prior session_serial# = blocking_session_serial#
                          and  sample_time= prior sample_time
order by sample_time
/
"
 fi
# --------------------------------------------------------------------------
# List DBID present in the repository
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_DBID" ];then
TITTLE="List dbid present in the repository"
SQL="
  select dbid, count(1) count from dba_hist_snapshot group by dbid;
"
# -------------------------------------------------------------
#  author : B. Polarski 2010 http://www.smenu.org
# -------------------------------------------------------------
elif [ "$METHOD" = "GEN_SQL_BIND" ];then
 if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  AND_SNAP1=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  ret=`exists_binds $SQL_ID`
  var=`echo $ret | awk '{ print $1}'`
  if [ $var -eq -1 ]; then
        echo 
        echo "No bind in  $SNAP1, but there are binds in these snap_id"
        echo "$ret" | grep -v '\-1'
      exit
  elif [ $var -eq 0 ]; then
      echo "This query has no binds"
      exit
  fi
unset SHEAD
SQL="

    prompt
    prompt  Warning : This query does not support mix of system generated named binds and user named binds within same query
    prompt            binds Timestamp are transformed into date type, affect index and partition pruning and loose their 'FFFFFF'
    prompt

    set lines 32000 head off feed off
    break on fdate on report
   set trimspool on
     with HIST_SQLBIND_PLANHASH as (
  SELECT   snap_id snap_id,
       dbid dbid,
       instance_number instance_number,
       sql_id sql_id,
       name name,
       position position,
       nvl2(cap_bv, v.cap_bv.dup_position, dup_position) dup_position,
       nvl2(cap_bv, v.cap_bv.datatype, datatype) datatype,
       nvl2(cap_bv, v.cap_bv.datatype_string, datatype_string) datatype_string,
       nvl2(cap_bv, v.cap_bv.character_sid, character_sid) character_sid,
       nvl2(cap_bv, v.cap_bv.precision, PRECISION) PRECISION,
       nvl2(cap_bv, v.cap_bv.scale, scale) scale,
       nvl2(cap_bv, v.cap_bv.max_length, max_length) max_length,
       nvl2(cap_bv, 'YES', 'NO') was_captured,
       nvl2(cap_bv, v.cap_bv.last_captured, NULL) last_captured,
       NVL2(CAP_BV, V.CAP_BV.VALUE_STRING, null) VALUE_STRING,
       NVL2(CAP_BV, V.CAP_BV.VALUE_ANYDATA, null) VALUE_ANYDATA,
       PLAN_HASH_VALUE
        FROM
       (SELECT   sql.snap_id,
           sql.dbid,
           sql.instance_number,
           sbm.sql_id,
           dbms_sqltune.extract_bind(sql.bind_data, sbm.position) cap_bv,
           sbm.name,
           sbm.position,
           sbm.dup_position,
           sbm.datatype,
           sbm.datatype_string,
           sbm.character_sid,
           sbm.precision,
           sbm.scale,
           SBM.MAX_LENGTH,
           sql.PLAN_HASH_VALUE
            from 
                  SYS.WRM\$_SNAPSHOT SN,
                  SYS.WRH\$_SQL_BIND_METADATA SBM,
                  sys.wrh\$_sqlstat SQL
           WHERE 
                  sn.snap_id       = sql.snap_id
           AND sn.dbid            = sql.dbid
           AND sn.instance_number = sql.instance_number
           AND sbm.sql_id         = sql.sql_id
           and SN.STATUS          = 0
       ) V
  )
     select  decode(position, 1,
                                  '-------------------------------------' ||chr(10) ||
                                  '-- Date :'||to_char(LAST_CAPTURED,'YYYY-MM-DD HH24:MI:SS')||chr(10)  ||
                                  '-------------------------------------' ||chr(10)|| chr(10)
                                   || 'alter session set NLS_DATE_FORMAT=''YYYY-MM-DD HH24:MI:SS'' ;' || chr(10)
                              , chr(10)
             )||
            'variable ' ||
             regexp_replace( name,':\D*[[:digit:]]*','a') ||
                                  to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
              || ' '
            || case DATATYPE
                       -- varchar2
                 when  1   then 'varchar2(4000)' || chr(10) || 'Exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                  to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                 || ':='''||  value_string || ''';'
                          -- number
                 when  2   then 'number'         || chr(10) || 'exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                  to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                 || ':='  ||  value_string || ';'
                          -- date
                 when  12  then 'varchar2(30)'   || chr(10) || 'exec '|| regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                  to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                        || ':='''||
                                        decode( sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                                to_char(anydata.accessdate(value_anydata),'YYYY-MM-DD HH24:MI:SS') )  || ''';'
                           -- char
                 when  96  then 'char(3072)'     || chr(10) || 'exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                 to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                 || ':='''||  value_string || ''';'
                           -- timestamp
                 when  180 then 'varchar2(26)'   || chr(10) || 'exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                 to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                         || ':='''||
                                         decode( sys.anydata.GETTYPEname(value_anydata), null,value_string,
                                                 to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS') ) || ''';'
                                                 ||chr(10)||'-- Warning: implicit timestamp to date conversion: the bind was a timestamp'
                                                 --to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS.FFFFFF') ) || ''';'
                           -- timestampTZ
                 when  181 then 'varchar2(26)'   || chr(10) || 'exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                 to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                          || ':='''||
                                         decode(  sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                                 to_char(anydata.accessTimestampTZ(value_anydata),'YYYY-MM-DD HH24:MI:SS') ) || ''';'
                                                 ||chr(10)||'-- Warning: implicit timestamp to date conversion: the bind was a timestamp'
                                                 --to_char(anydata.accessTimestampTZ(value_anydata),'YYYY-MM-DD HH24:MI:SS.FFFFFF') ) || ''';'
                 when  112 then 'CLOB'           || chr(10) || 'exec '||regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                  to_char(decode(regexp_replace( name,':\D*([[:digit:]]*)','\1'),null,position,
                                           regexp_replace( name,':\D*([[:digit:]]*)','\1')))
                                           || ':='''||  value_string || ''';'
               else
                               'Varchar2(4000)'  || chr(10) || 'exec '|| regexp_replace( name,':\D*[[:digit:]]*',':a') ||
                                  to_char(regexp_replace( name,':\D*([[:digit:]]*)','\1'))
                                 || ':='''||  value_string || ''';'
               end line
     from HIST_SQLBIND_PLANHASH where sql_id = '$SQL_ID' $AND_DBID $AND_SNAP1
order by PLAN_HASH_VALUE,snap_id,last_captured,position 
/
set long 32000 longchunk 32000
select regexp_replace( sql_text,'(:)\D*([[:digit:]]*)','\1a\2')sql_text 
     from dba_hist_sqltext where sql_id = '$SQL_ID' $AND_DBID
/
"
# -------------------------------------------------------------
# --------------------------------------------------------------------------
# List Binds for a given SQL_ID
# --------------------------------------------------------------------------
elif [ "$METHOD" = "SHOW_BIND" ];then
  # only set AND_SNAP if there is a request, otherwise don't use it
  if [ -n "$SNAP1" -a -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  elif [ -n "$SNAP1" -a -n "$SNAP2" ];then
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  fi
SQL="col NAME for a16
col value_string for a40 head 'Value'
col pos head 'pos' format a4
col datatype_string head 'Data|type'
col name head Name justify c
col snap_id head 'snap_id'
col lc head 'Date capture'

break on snap_id on report
select snap_id, last_captured lc, pos, name, value_string, DATATYPE_STRING from (
  select
         snap_id, to_char(LAST_CAPTURED,'YYYY-MM-DD HH24:MI') last_captured ,
         to_char(' '||position) pos, '  '||NAME name,
         decode ( VALUE_STRING, null,
             case DATATYPE
                 when  1   then
                              decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessVarchar2(value_anydata ) )
                 when  2   then
                              decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessNumber(value_anydata ) )
                 when  12  then decode( sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                            to_char(anydata.accessdate(value_anydata),'YYYY-MM-DD HH24:MI:SS') ) 
                 when  96  then
                           decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessChar(value_anydata ) )
                           -- timestamp
                 when  180 then
                              decode( sys.anydata.GETTYPEname(value_anydata), null,value_string,
                                          to_char(anydata.accessTimestamp(value_anydata),'YYYY-MM-DD HH24:MI:SS') )
                           -- timestampTZ
                 when  181 then
                           decode(  sys.anydata.GETTYPEname(value_anydata), null, value_string,
                                        to_char(anydata.accessTimestampTZ(value_anydata),'YYYY-MM-DD HH24:MI:SS') )
                           -- clob
                 when  112 then
                           decode( sys.anydata.GETTYPEname(value_anydata), null, value_string, anydata.AccessClob(value_anydata ) )
               else
                                   value_string
               end  ,
        value_string ) VALUE_STRING,
        DATATYPE_STRING
   from
       dba_hist_sqlbind
where
       sql_id = '$SQL_ID'  $AND_DBID $AND_SNAP
order by
       snap_id desc, POSITION desc
) where rownum < $ROWNUM
/
"
# --------------------------------------------------------------------------
# List stats of SQL accross SNAPS
# --------------------------------------------------------------------------
elif [ "$METHOD" = "STATS_SQL_HIST" ];then
TITTLE="Show SQL stats for $SQL_ID"
get_snap_beg_end
 if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  AND_SNAP=" and b.snap_id >= $SNAP1 and b.snap_id <= $SNAP2 "
SQL="
col executions_delta head 'Exec' format 999999
col plan_hash_value head 'Plan|hash value' justify c format 99999999999
col buffer_gets_delta head 'Gets'
col optimizer_cost head 'Optim|cost' format 999999
col ROWS_PROCESSED_DELTA head 'Row|processed' justify c
col ctd head 'cpu|Time(ms)' format 99999990.9 justify c
col disk_reads_delta head 'Disk|reads' format 999990.9 justify c
col iowait_delta head 'Cluster|iowait' format 999990.9 justify c
col apwait_delta head 'App|wait' format 9999990.9
col ccwait_delta head 'Concurr|iowait' format 999999
col direct_writes_delta head 'direct|write|wait'
col etd head 'Elapsed|time(ms)' format 99999990.9 justify c
col fetches_delta head 'Fetches|delta' format 99999990 justify c
col begtim head 'Snap Date' for a16
set lines 190
  Select
       to_char(begin_interval_time ,'YYYY-MM-DD HH24:MI') begtim,
       plan_hash_value,
       optimizer_cost,
       executions_delta    ,
       buffer_gets_delta   ,
       ROWS_PROCESSED_DELTA,
       fetches_delta ,
       ELAPSED_TIME_DELTA/1000 etd,
       CPU_TIME_DELTA/1000 ctd,
       disk_reads_delta,
       iowait_delta/1000 iowait_delta       ,
       apwait_delta/1000  apwait_delta      ,
       ccwait_delta/1000  ccwait_delta, 
       direct_writes_delta
   from
      dba_hist_snapshot a,
      dba_hist_sqlstat  b
   where 
            a.snap_id = b.snap_id  and b.DBID=$DBID 
         and b.instance_number=$INST_NUM
         and b.instance_number = a.instance_number $AND_SNAP
   and sql_id = '$SQL_ID'
   order by
     1 desc ;
"
# --------------------------------------------------------------------------
# List event histograms
# --------------------------------------------------------------------------
elif [ "$METHOD" = "EVENTS_HISTOGRAM" ];then
  if [ -z "$EVENT_NAME" ];then
        echo "I need an event name ...."
        exit
  fi
  # correction for the lag
  if [ -n "$SNAP1" ];then
        if [ -z "$SNAP2" ];then
           var=` get_last_snap'`
           if [ ! $SNAP1  -eq $var ];then
              SNAP2=`expr $SNAP1 + 1`
           else
              SNAP2=$var
              SNAP1=`expr $SNAP1 - 1`
           fi
        fi
   fi


   if [ -z "$SNAP1" ];then
        VAR=`get_snap_beg_end`
        VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
        SNAP1=`echo $VVAR | cut -f2 -d' '`
        SNAP2=`echo $VVAR | cut -f2 -d' '`
   elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
   fi
     SNAP2=`expr $SNAP2 + 1`
SQL="
  col snap_id for 999999 head 'Snap|id' justify c
  col ws format 9999999990.99 head 'Time Wait(s)'
  col snap_id for 999999 head 'Snap|id' justify c
  col tw head 'Tot waits' form 999999999
  col wm form 99999999999999 head 'Wait milli'
  col event_name format a56


   with v1 as (
                 select  SNAP_ID, INSTANCE_NUMBER inst, EVENT_NAME, WAIT_TIME_MILLI wm , wait_count  wc
                         from dba_hist_event_histogram
       where EVENT_NAME ='$EVENT_NAME'
             and snap_id >=  $SNAP1 and snap_id <= $SNAP2 
      order by instance_number, snap_id, WAIT_TIME_MILLI
     ),
   v2 as (
                 select  SNAP_ID -1 snap_id, INSTANCE_NUMBER inst,  WAIT_TIME_MILLI wm, wait_count  wc
                         from dba_hist_event_histogram
       where EVENT_NAME ='$EVENT_NAME'
             and snap_id >= ( $SNAP1) and snap_id <= ($SNAP2 )
      order by instance_number, snap_id, WAIT_TIME_MILLI
     )
    select  snap_id, inst, event_name, wm, wc from (
    select  v1.SNAP_ID, v1.inst, v1.EVENT_NAME, v1.wm, 
     case 
        when v1.wc is null then 0
        when v2.wc is null then 0
        when v1.wc > v2.wc then v1.wc-v2.wc
        when v2.wc > v1.wc then v2.wc-v1.wc
        else
            0
    end wc
    from 
        v1, v2
    where 
             v1.inst=v2.inst  (+)
         and v1.snap_id=v2.snap_id  (+)
         and v1.wm = v2.wm (+)
    order by inst, snap_id, wm
  ) where wc > 0 and snap_id > $SNAP1
/
"
# --------------------------------------------------------------------------
# List system events
# --------------------------------------------------------------------------
elif [ "$METHOD" = "SYSTEM_EVENTS" ];then
  # correction for the lag
  if [ -n "$SNAP1" ];then
        if [ -z "$SNAP2" ];then
           var=` get_last_snap'`
           if [ ! $SNAP1  -eq $var ];then
              SNAP2=`expr $SNAP1 + 1`
           else
              SNAP2=$var
              SNAP1=`expr $SNAP1 - 1`
           fi
        fi
   fi


   if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f2 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  AND_SNAP=" snap_id >=  $SNAP1 and snap_id <= $SNAP2  "
  if [ "$ORDER_BY" = "WAIT_TIME" ];then
     ORDER_BY=" order by SNAP_ID desc,TIME_WAITED_MICRO/1000000 desc"
  elif [ "$ORDER_BY" = "WAIT_CLASS" ];then
     ORDER_BY=" order by dbid,SNAP_ID desc, WAIT_CLASS,TIME_WAITED_MICRO/1000000 desc"
  else
     ORDER_BY=" order by dbid,SNAP_ID desc, EVENT_NAME,TIME_WAITED_MICRO/1000000 desc"
  fi
  if [ -n "$CLASS" ];then
       AND_CLASS="and wait_class ='$CLASS'"
  fi
  if [ -n "$EVENT_NAME" ];then
       AND_EVENT="and EVENT_NAME ='$EVENT_NAME'"
  fi
SQL=" 
col WAIT_CLASS for a20
col ws format 9999999990.99 head 'Time Wait(s)'
col snap_id for 999999 head 'Snap|id' justify c
col TOTAL_WAITS head 'Tot waits' form 99999.9
col TOTAL_TIMEOUTS head 'Tot Timeouts' form 99999.9
col wait_class form a14 head 'Wait class'
col event_name format a56
col snap_begin for a21 head 'Date'
break on dbid on  snap_id on snap_begin on  wait_class on report
set lines 167

select a.SNAP_ID, a.instance_number, to_char(BEGIN_INTERVAL_TIME,'YYYY-MM-DD HH24:MI:SS') snap_begin ,
       WAIT_CLASS, EVENT_NAME,
       decode(lag_Waits,0,0,TOTAL_WAITS - lag_waits) TOTAL_WAITS ,
       decode(nvl(total_timeouts,0),0,0,TOTAL_TIMEOUTS - lag_timeouts) TOTAL_TIMEOUTS,
       ws - lag_ws ws
from
(
select SNAP_ID, dbid, instance_number,
       WAIT_CLASS,
       EVENT_NAME,
       TOTAL_WAITS,TOTAL_TIMEOUTS,
       TIME_WAITED_MICRO/1000000 ws,
       lag(TOTAL_WAITS,0)  over (partition by event_name order by dbid,instance_number, snap_id ) lag_waits,
       lag(TOTAL_timeouts)  over (partition by event_name order by dbid,instance_number, snap_id ) lag_timeouts,
       lag(TIME_WAITED_MICRO/1000000)  over (partition by event_name order by dbid,instance_number,snap_id) lag_ws
from SYS.DBA_HIST_SYSTEM_EVENT
 where $AND_SNAP $AND_DBID $AND_CLASS $AND_EVENT $ORDER_BY
) a,
 sys.wrm\$_snapshot b
where 
        a.dbid=b.dbid and a.snap_id = b.snap_id 
    and ws - a.lag_ws > 0 and lag_ws is not null
 order by 2,3,1 desc, 8 desc;
"

#order by instance_number, snap_id desc,ws 
# --------------------------------------------------------------------------
# List enqueue events
# --------------------------------------------------------------------------

elif [ "$METHOD" = "ENQUEUE" ];then
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f2 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
SQL=" col REQ_REASON for a30
col evt format a30
select $F_INST_NUM EQ_TYPE,REQ_REASON,TOTAL_REQ#,TOTAL_WAIT#,
       SUCC_REQ#, FAILED_REQ#, CUM_WAIT_TIME,event#
       --  ,(select event_name from  sys.wrh\$_event_name where event_id = event# )evt
       --  , event_name
     from SYS.DBA_HIST_ENQUEUE_STAT a
      -- , sys.dba_hist_system_event b
    where a.snap_id between  $SNAP1 and $SNAP2  and a.dbid='$DBID'
        --    and a.snap_id = b.snap_id
        --    and a.dbid = b.dbid 
        --    and a.instance_number = b.instance_number
        --    and a.event# = b.event_id
   order by a.instance_number ;
"
# --------------------------------------------------------------------------
# List events from DBA_HIST_ACTIVE_SESS
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_EVENTS" ];then
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f2 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  fi
  AND_SNAP=" and snap_id = '$SNAP1' "
  if [ -n "$SNAP2" ];then
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id < $SNAP2 "
  fi

SQL="col event format a28
col st for a14 head 'Time'
col user_id for 999 head 'Usr|Id'
col tw head 'Time|wait(s)' for 99990.9
col instance_number head 'In|st' for 99
col session_id head 'Sess|id' for 99999
col ser# for 99999
col bs form a12 head 'Blocking| Session'
select to_char(SAMPLE_time,'MM-DD HH24:MI:SS') st, instance_number, session_id, session_Serial# ser#,
     user_id, sql_id, EVENT, time_waited/100 tw, P1, p2, p3 , 
     to_char(blocking_Session)||'.'||to_char(blocking_session_serial#) bs
from DBA_HIST_ACTIVE_SESS_HISTORY where event like '%$FEVENT%' $AND_SNAP $AND_DBID
order by st;
"
# --------------------------------------------------------------------------
# show some metrics names
# --------------------------------------------------------------------------
elif [ "$METHOD" = "GN" ];then
SQL="break on metric_name on report 
select metric_name, begin_time, end_time, value from (
select metric_name, to_char(begin_time,'YYYY-MM-DD HH24:MI:SS')begin_time,
                         to_char(end_time,'YYYY-MM-DD HH24:MI:SS')end_time,  round(value,1) value from 
            v\$sysmetric_history where metric_id = $MET_ID order by begin_time desc)
where rownum <= $ROWNUM;"

# --------------------------------------------------------------------------
# show some metrics  stats
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PGASTAT" ];then
  if [ -z "$SNAP1"  -a -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    VAR0=`echo $VVAR | cut -f1 -d' '`
    SNAP1=`expr $VAR0 - $ROWNUM`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
    SNAP1=`expr $SNAP1 - 1`

#aggregate PGA auto target
#global memory bound
#max processes count
#process count
#PGA memory freed back to OS
#extra bytes read/written
#total PGA used for auto workareas
#over allocation count
#bytes processed
#total PGA allocated
#maximum PGA allocated
#recompute count (total)
#cache hit percentage
#maximum PGA used for manual workareas
#total PGA used for manual workareas
#maximum PGA used for auto workareas
#total PGA inuse
#aggregate PGA target parameter
#total freeable PGA memory


TITTLE="List pga stats from AWR"
SQL="
col tpa  head 'Ttotal PGA|in use' justify c
col tpi  head 'Max PGA|Allocated'  justify c
col tpx  head 'Tot PGA|Allocated' justify c
col tpfm head 'Tot freeable|PGA Mem' justify c
col tpuw head 'Tot PGA|Manual'justify c
col pc   head 'Process|count' justify c
col maxp head 'Max PGA|Auto' justify c

select a.snap_id ,
        to_char(s.BEGIN_INTERVAL_TIME,'YY-MM-DD HH24:mi:ss') begin_snap,
        round( extract( day from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *24*60*60*60+
                    extract( hour from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *60*60+
                    extract( minute from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME )* 60 +
                    extract( second from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME )) snap_len ,
        tpa,tpi ,tpx,tpfm,tpuw,pc,maxp
from
      ( select snap_id, avg(tpa) tpa, avg(tpi) tpi,avg(tpx)tpx,avg(tfpm)tpfm,avg(tpuw)tpuw,avg(pc)pc,avg(maxp)maxp
             from
               ( select e.snap_id,
                    case
                        when name = 'total PGA inuse' then round(value/1048576)
                    end tpi,
                    case
                       when name = 'maximum PGA allocated' then  round(value/1048576)
                    end tpx,
                    case
                       when name = 'total PGA allocated' then  round(value/1048576)
                    end tpa,
                    case
                       when name = 'total freeable PGA memory' then  round(value/1048576)
                    end tfpm,
                    case
                       when name = 'total PGA used for manual workareas' then  round(value/1048576)
                    end tpuw,
                    case
                       when name = 'process count' then  value
                    end pc,
                    case
                       when name = 'maximum PGA used for auto workareas' then  round(value/1048576)
                    end maxp
                 from DBA_HIST_PGASTAT e, DBA_HIST_SNAPSHOT s
                 where s.snap_id = e.snap_id
                     and e.instance_number = s.instance_number
                     and e.instance_number = $INST_NUM
                     and e.name
                         in ( 'total PGA inuse','total PGA allocated','maximum PGA allocated','total freeable PGA memory',
                              'total PGA used for manual workareas','process count','maximum PGA used for auto workareas'
                            )
               ) group by snap_id
      )a,
      sys.wrm\$_snapshot s
where  a.snap_id           = s.snap_id     and
       s.instance_number   = $INST_NUM     and
       a.snap_id between  $SNAP1 and $SNAP2
order by a.snap_id desc
/
"
# --------------------------------------------------------------------------
# show some metrics names
# --------------------------------------------------------------------------
elif [ "$METHOD" = "MET" ];then
SQL="col METRIC_ID head 'Metric|Id' justify c
col METRIC_NAME head 'metric name'
col METRIC_UNIT head 'metric unit'
select distinct METRIC_ID, METRIC_NAME,METRIC_UNIT from v\$metricname order by METRIC_NAME;"
# --------------------------------------------------------------------------
# show some metrics  stats
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LSI" ];then
  if [ -z "$SNAP1"  -a -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    VAR0=`echo $VVAR | cut -f1 -d' '`
    SNAP1=`expr $VAR0 - $ROWNUM`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
    SNAP1=`expr $SNAP1 - 1`
TITTLE="List Metrics history stats from AWR"
SQL="
col begin_snap for a18
col end_snap for a22
col inst forma 9999
col snap_id for 999999
col snap_len for 99999 head 'Snap|len(s)' justify c
col dbc for 9999990.0 head 'DB blk|chg/txn' justify c
col lio for 9999990.0 head 'gets/txn'
col respt for 999990.0 head 'Response|Time(s)/txn' justify c
col max_respt for 999990.0 head 'Max|Response|Time(s)/txn' justify c
col phw for 9999990.0 head 'Physic.|blocks Write/s' justify c
col phr for 9999990.0 head 'Physic.|blocks Read/s' justify c
col redo for 99999990.0 head 'Redo |Write/s' justify c
col srv for 9999990.0 head 'Sql|Resp/s' justify c
col net for 999999990.0 head 'Network|traffic/s' justify c
col execs for 999990.0 head 'Exec/s' justify c
col tpc for 999990 head 'Total|parse/s' justify c
set lines 190 
select a.snap_id ,
        to_char(s.BEGIN_INTERVAL_TIME,'YY-MM-DD HH24:mi:ss') begin_snap,
        round( extract( day from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *24*60*60*60+
                    extract( hour from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *60*60+
                    extract( minute from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME )* 60 +
                    extract( second from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME )) snap_len ,
         dbc, lio, respt, max_respt, phw, redo, phr,  srv, net, tpc, execs
from
      ( select snap_id, avg(dbc) dbc, avg(lio) lio, avg(respt) respt , 
                        max(respt)max_respt, avg(phw)phw,
                        avg(redo)redo, avg(phr) phr, avg(srv) srv, avg(net)net,avg(execs)execs,avg(tpc)tpc
             from 
               ( select m.snap_id,
                    case 
                        when metric_name = 'DB Block Changes Per Txn' then value
                    end dbc,
                    case 
                       when metric_name = 'Logical Reads Per Txn' then  value
                    end lio,
                    case 
                       when metric_name = 'Response Time Per Txn' then  value
                    end respt,
                    case 
                       when metric_name = 'Executions Per Sec' then  value
                    end execs,
                    case 
                       when metric_name = 'Physical Writes Per Sec' then  value
                    end phw,
                    case 
                       when metric_name = 'Redo Generated Per Sec' then  value
                    end  redo,
                    case 
                       when metric_name = 'Physical Reads Per Sec' then  value
                    end  phr,
                    case 
                       when metric_name = 'Total Parse Count Per Sec' then  value
                    end  tpc,
                    case 
                       when metric_name = 'SQL Service Response Time' then  value
                    end  srv,
                    case 
                       when metric_name = 'Network Traffic Volume Per Sec' then  value/1048576
                    end  net 
                 from   sys.WRH\$_SYSMETRIC_HISTORY m, sys.WRH\$_METRIC_NAME mn , DBA_HIST_SNAPSHOT s
                 where s.snap_id = m.snap_id and m.group_id = mn.group_id and m.metric_id = mn.metric_id
                     and m.instance_number = s.instance_number
                     and m.instance_number = $INST_NUM
                     and mn.metric_name  
                         in ( 'DB Block Changes Per Txn','Logical Reads Per Txn','Response Time Per Txn','Executions Per Sec',
                              'Physical Writes Per Sec','Redo Generated Per Sec','Physical Reads Per Sec','SQL Service Response Time',
                              'Network Traffic Volume Per Sec'
                            )
               ) group by snap_id
      )a,
      sys.wrm\$_snapshot s
where  a.snap_id           = s.snap_id            and
       s.instance_number   = $INST_NUM     and
       a.snap_id between  $SNAP1 and $SNAP2 
order by a.snap_id desc
/
"
# --------------------------------------------------------------------------
# show most important system stats
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LST" ];then
  if [ -z "$SNAP2"  -a -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    VAR0=`echo $VVAR | cut -f1 -d' '`
    SNAP1=`expr $VAR0 - $ROWNUM`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
    SNAP1=`expr $SNAP1 - 1`
TITTLE="List system stats from AWR"
SQL="
set pages 66 lines 190
col dbtime for 999,999.99
col begin_snap for a22
col end_snap for a22
col inst forma 9999
col snap_id for 999999
col ratio for 99990.9 head 'Ratio|dbt/l'
col snap_len for 990.9 head 'snap len|(minute)' justify c
col bckg for 99999 head 'Background|Time(m)' justify c
col prs for 99999 head 'Parse|Time(m)' justify c
col HardParse for 99999 head 'Hard|Parse|Time(m)' justify c
col PLSQLexec for 99999 head 'PL/SQL|exec time(m)' justify c
col SQLexec for 99999.0 head 'SQL exec|time(m)' justify c
col DBCPU for 99999.0 head 'DB On|cpu(m)' justify c
col DBtime for 99999.0 head 'DB Time|(minute)' justify c
select snap_id,begin_snap,snap_len,DBtime,DBtime/snap_len ratio, DBCpu, SQLexec,PLSQLexec,prs,HardParse,Bckg  -- ,tpc 
from (
select a.snap_id , 
        to_char(s.BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss') begin_snap,
        round(( extract( day from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *24*60*60*60+
                    extract( hour from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME) *60*60+
                    extract( minute from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME ) *60 +
                    extract( second from s.END_INTERVAL_TIME-s.BEGIN_INTERVAL_TIME ))/60,1) snap_len ,
       round((dbt - lag(dbt) over (order by a.snap_id) )/1000000/60,1) DBtime ,
       round((dbc - lag(dbc) over (order by a.snap_id) )/1000000/60,1) DBCpu ,
       round((sqlexec - lag(sqlexec) over (order by a.snap_id) )/1000000/60,1) SQLexec ,
       round((plexec - lag(plexec) over (order by a.snap_id) )/1000000/60,1) PLSQLexec ,
       round((prs - lag(prs) over (order by a.snap_id) )/1000000/60,1) prs ,
       round((hardp - lag(hardp) over (order by a.snap_id) )/1000000/60,1) HardParse ,
       round((bckg - lag(bckg) over (order by a.snap_id) )/1000000/60,1) Bckg 
       --, round((tpc - lag(tpc) over (order by a.snap_id) )) tpc 
from
      ( select snap_id, max(dbt) dbt,max(dbc) dbc, max(sqlexec) sqlexec , max(plexec)plexec,
                        max(hardp)hardp, max(bckg) bckg, max(prs) prs --, max(tpc)tpc
             from 
               ( select m.snap_id,
                    case 
                        when stat_name = 'DB time' then value
                    end dbt,
                    case 
                       when stat_name = 'DB CPU' then  value
                    end dbc,
                    case 
                       when stat_name = 'sql execute elapsed time' then  value
                    end sqlexec,
                    case 
                       when stat_name = 'PL/SQL execution elapsed time' then  value
                    end plexec,
                    case 
                       when stat_name = 'hard parse elapsed time' then  value
                    end hardp,
                    case 
                       when stat_name = 'background cpu time' then  value
                    end  bckg,
                    -- case 
                    --    when stat_name = 'Total Parse Count Per Sec' then  value
                    -- end  tpc,
                    case 
                       when stat_name = 'parse time elapsed' then  value
                    end  prs
                 from sys.WRH\$_SYS_TIME_MODEL m, sys.WRH\$_STAT_NAME nm, DBA_HIST_SNAPSHOT s
                 where s.snap_id = m.snap_id
                     and m.stat_id = nm.stat_id
                     and m.dbid  = nm.dbid
                     and m.instance_number = s.instance_number
                     and m.instance_number = $INST_NUM
                     and nm.stat_name  
                         in ( 'DB time', 'DB CPU','sql execute elapsed time','PL/SQL execution elapsed time',
                               'hard parse elapsed time','background cpu time','parse time elapsed')
               ) group by snap_id
      )a,
      sys.wrm\$_snapshot s
where  a.snap_id           = s.snap_id            and
             s.instance_number   = $INST_NUM    and
             a.snap_id between  $SNAP1 and $SNAP2 
order by a.snap_id desc
)
/
"
# --------------------------------------------------------------------------
# show sql text from dba_hist_sql_text
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SHOW_TEXT" ];then
   SQL="set pages 0 long 32767 lines 1500 trimspool on head off
   col sql_text head 'sql_text : $SQL_ID' format a32767
   select sql_text  from dba_hist_sqltext  where   sql_id = '$SQL_ID';"
# --------------------------------------------------------------------------
# Purge snapshots
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PURGE" ];then
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
SQL="EXEC dbms_workload_repository.drop_snapshot_range(low_snap_id=>$SNAP1, high_snap_id=>$SNAP2);"


# --------------------------------------------------------------------------
# List Buffer busy wait
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LBW" ];then
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
SQL="column name format a40
set lines 130
column begin_interval_time format a15
set wrap off
  select ws.begin_interval_time,BUFFER_BUSY_WAITS_DELTA buffer_busy,
         PHYSICAL_WRITES_DELTA writes,
         ROW_LOCK_WAITS_DELTA row_locks,
         owner||'.'||object_name name
   from dba_hist_seg_stat h,
        dba_objects do ,
        sys.WRM\$_SNAPSHOT ws
where      h.SNAP_ID >= $SNAP1  and h.SNAP_ID <= $SNAP2 
      and h.BUFFER_BUSY_WAITS_DELTA>1
      and do.object_id=h.obj#
      and ws.snap_id=h.snap_id
order by BUFFER_BUSY_WAITS_DELTA
/
"

# --------------------------------------------------------------------------
# redo and lgw stats
# --------------------------------------------------------------------------
elif [ "$METHOD" = "REDO_LGW" ];then
# adapted from Savinon blog :
# https://savvinov.com/2014/10/14/log-buffer-space/
  if [ -n "$BACK_SNAP" ];then
     SNAP2=`get_last_snap`
     SNAP1=`expr $SNAP2 - $BACK_SNAP` 
  elif [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     var=`get_last_snap'`
     if [ ! $SNAP1  -eq $var ];then
            SNAP2=`expr $SNAP1 + 1`
     else
           SNAP2=$var
           SNAP1=`expr $SNAP1 - 1`
     fi
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
TITTLE="List redo and LGWR stats"
SQL="set lines 190 pages 66
col REDO_GEN_MB_PER_SEC head 'Redo mb/s'
col LGWR_PCT_BUSY head 'LGWR|% Busy' justify c
col AVG_REQUESTS_PER_LOG_WRITE head 'Avg Req|per log write' justify c
col REDO_WRITE_SPEED head 'Redo write|speed (ms)' justify c
col AVG_REDO_WRITE_SIZE head 'Avg redo|size(m)' justify c
col AVG_LFS head 'Avg | log file |sync (ms)' justify c
col AVG_LFPW head 'Avg log| file parallel|write(ms)' justify c
col LFS_NUM_WAITS head 'Log file|sync counts' justify c
col LFPW_NUM_WAITS head 'log file|write counts' justify c
col MAX_CONCURRENCY head 'Max|Concurrency)' justify c

with
lfs as
(
  select lag(e.snap_id) over(partition by e.event_name ORDER BY e.snap_id) snap_id,
         e.total_waits - lag(e.total_waits) over (partition by e.event_name order by e.snap_id) waits_delta,
         e.time_waited_micro - lag(e.time_waited_micro) OVER (PARTITION BY e.event_name ORDER BY e.snap_id) time_delta
  from dba_hist_system_event e
  where e.event_name = 'log file sync' 
  and snap_id >= $SNAP1 and snap_id <= $SNAP2
),
lfpw as
(
  select lag(e.snap_id) over(partition by e.event_name ORDER BY e.snap_id) snap_id,
         e.total_waits - lag(e.total_waits) over (partition by e.event_name order by e.snap_id) waits_delta,
         e.time_waited_micro - lag(e.time_waited_micro) OVER (PARTITION BY e.event_name ORDER BY e.snap_id) time_delta
  from dba_hist_system_event e
  where e.event_name = 'log file parallel write'
  and snap_id >= $SNAP1 and snap_id <= $SNAP2
),
redo as
(
  SELECT  lag(snap_id) over(partition by stat_name ORDER BY snap_id) snap_id,
          (VALUE - lag(VALUE) OVER (PARTITION BY stat_name ORDER BY snap_id))/1024/1024 redo_size
  FROM dba_hist_sysstat
  WHERE stat_name = 'redo size'
  and snap_id >= $SNAP1 and snap_id <= $SNAP2
  ORDER BY snap_id DESC
),
snap as
(
  select lag(snap_id) over(ORDER BY snap_id) snap_id,
         trunc(begin_interval_time, 'mi') begin_interval_time,
         end_interval_time - begin_interval_time interval_duration
  from dba_hist_snapshot
  where snap_id >= $SNAP1 and snap_id <= $SNAP2
),
sn as
(
  select snap_id,
         begin_interval_time,
         extract(hour from interval_duration)*3600+
         extract(minute from interval_duration)*60+
         extract(second from interval_duration) seconds_in_snap
  from snap
  where snap_id >= $SNAP1 and snap_id <= $SNAP2
),
ash as
(
  select lag(snap_id) over(ORDER BY snap_id) snap_id,
         max(active_sess) max_concurrency
  from
  (
    select snap_id, sample_time, count(*) active_sess
    from dba_hist_active_sess_history ash
    where event = 'log file sync'
  and snap_id >= $SNAP1 and snap_id <= $SNAP2
    group by snap_id, sample_time
  )
  group by snap_id
),
requests as
(
  select lag(snap_id) over(ORDER BY snap_id) snap_id, avg(p3) avg_lfpw_requests
  from dba_hist_active_sess_history ash
  where event = 'log file parallel write'
  and snap_id >= $SNAP1 and snap_id <= $SNAP2
  group by snap_id
)
select sn.snap_id,to_char(begin_interval_time,'YYYY-MM-DD HH24:MI:SS') fdate,
       round(redo.redo_size/seconds_in_snap,2) redo_gen_MB_per_sec,
       round(100*lfpw.time_delta/1e6/seconds_in_snap) lgwr_pct_busy,
       round(avg_lfpw_requests, 2) avg_requests_per_log_write,
       round(1e6*redo.redo_size/lfpw.time_delta, 2) redo_write_speed,
       round(redo.redo_size/lfpw.waits_delta, 2) avg_redo_write_size,
       round(lfs.time_delta/lfs.waits_delta/1000,2) avg_lfs,
       round(lfpw.time_delta/lfpw.waits_delta/1000,2) avg_lfpw,
       lfs.waits_delta lfs_num_waits,
       lfpw.waits_delta lfpw_num_waits,
       max_concurrency
from lfs,
     lfpw,
     sn,
     redo,
     ash,
     requests
where lfs.snap_id (+) = sn.snap_id
and lfpw.snap_id (+) = sn.snap_id
and redo.snap_id (+) = sn.snap_id
and ash.snap_id = sn.snap_id
and requests.snap_id = sn.snap_id
order by begin_interval_time desc
/
"

# --------------------------------------------------------------------------
elif [ "$METHOD" = "BBW" ];then
# Adapted to AWR from a query of Tim Gorman  for statspack
NBR_DAYS=${NBR_DAYS:-1}
TITTLE="List Buffer busy wait"
SQL="clear breaks computes
break on day skip 1 on object_type on report
select
   yyyymmdd sort0,
   daily_ranking sort1,
   day,
   object_type,
   owner,
   object_name,
   buffer_busy_waits
from (select to_char(ss.startup_time, 'YYYYMMDD') yyyymmdd, to_char(ss.startup_time, 'DD-MON') day, o.object_type, o.owner,
     o.object_name, sum(s.buffer_busy_waits) buffer_busy_waits,
rank () over (partition by to_char(ss.startup_time, 'YYYYMMDD') order by sum(s.buffer_busy_waits) desc) daily_ranking
from
       ( select dbid, instance_number, dataobj#, obj#, snap_id,
              nvl(decode(greatest(buffer_busy_waits_total,
              nvl(lag(buffer_busy_waits_total) over (partition by dbid, instance_number, dataobj#, obj# order by snap_id),0)),
              buffer_busy_waits_total,
              buffer_busy_waits_total - lag(buffer_busy_waits_total) over (partition by dbid, instance_number, dataobj#, obj# order by snap_id),
              buffer_busy_waits_total), 0) buffer_busy_waits
        from DBA_HIST_SEG_STAT
        ) s,
        sys.wrh\$_seg_stat_obj o,
        sys.wrm\$_snapshot ss
where o.dataobj# = s.dataobj#
and o.obj# = s.obj#
and o.dbid = s.dbid
and ss.snap_id = s.snap_id
and ss.dbid = s.dbid
and ss.instance_number = s.instance_number
and ss.startup_time between (sysdate - $NBR_DAYS) and sysdate
    group by
         to_char(ss.startup_time, 'YYYYMMDD'),
         to_char(ss.startup_time, 'DD-MON'),
         o.object_type,
         o.owner,
         o.object_name
order by yyyymmdd, buffer_busy_waits)
where daily_ranking <= 10 order by sort0, sort1
/
"
# --------------------------------------------------------------------------
# List snapshots with sql id
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_SNAP_2" ];then
TITTLE="List snapid which contains SQL_ID=$SQL_ID"
if [ -n "$SNAP1" ];then
   AND_SNAP1=" and s.snap_id >= $SNAP1"
fi
SQL="
set lines 155
col execs for 999999999
col avg_etime for 99999999.9 head 'Avg|exec|Time(ms)'
col etime for 999999999.9 head 'Total exec|Time(s)' justify c
col avg_lio for 999999999 head 'Avg Gets'
col begin_interval_time for a22 head 'Begin interval| time' justify c
col snap_id form 9999999 head 'Snap'
col node for 9999 head 'Inst'
col plan_hash_value head 'Plan hash| Value'
col Execs for 9999999 head 'Execs'
col OPTIMIZER_COST head 'Cost' for 99999
col dreads head 'Disk|Reads' format 99999999
col twaits head 'Wait|time(ms|per exec)' format 9999999

break on plan_hash_value on startup_time skip 1
select
      ss.snap_id, ss.instance_number node, to_char(begin_interval_time,'YYYY-MM-DD HH24:MI:SS') begin_interval_time,
      sql_id, plan_hash_value, OPTIMIZER_COST,
        nvl(executions_delta,0) execs,
      round( elapsed_time_delta/1000000,1) etime,
     round((elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000,1) avg_etime,
     (buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio,
     (DISK_READS_DELTA/decode(nvl(DISK_READS_DELTA,0),0,1,executions_delta)) dreads,
     round((IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/
                decode(executions_delta,0,1,executions_delta)/1000,1) twaits
from
     DBA_HIST_SQLSTAT S,
     DBA_HIST_SNAPSHOT SS
where sql_id = '$SQL_ID'  and S.dbid=SS.dbid $AND_S_DBID $AND_SNAP1
  and ss.snap_id = S.snap_id
  and ss.instance_number = S.instance_number
  and executions_delta > 0
order by 3 desc, 1 , 2 ;
"

# --------------------------------------------------------------------------
# SHOW TASK report for an SQL_PROFLE
# --------------------------------------------------------------------------
elif [ "$METHOD" = "SHOW_TASK" ];then
SQL="
SET LONG 10000 longchunksize 1000
set PAGESIZE 333 LINESIZE 1024 head off 
SELECT DBMS_SQLTUNE.report_tuning_task('$TASK') AS recommendations FROM dual;
"
# --------------------------------------------------------------------------
# List  SQL_PROFILE
# --------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_ADV_PRF" ];then
SQL="col DESCRIPTION format a50
select TASK_NAME,DESCRIPTION,STATUS, LAST_MODIFIED from dbA_advisor_tasks where task_name like '${SQL_PRF}%';"

# --------------------------------------------------------------------------
#    List plan that make uses of an object (table or index)
# --------------------------------------------------------------------------
elif [ "$METHOD" = "PLAN_OBJ" ];then
     TITTEL="List plan that refers  to $TABLE"
     if [ -n "$OWNER" ];then
        P_AND_OWNER=" p.object_owner=upper('$OWNER') "
        AND_OWNER=" owner=upper('$OWNER') "
     fi
if [ -n "$SNAP1" ];then
   AND_SNAP1=" and p.snap_id >= $SNAP1"
   S_AND_SNAP1=" and s.snap_id >= $SNAP1"
   if [ -n "$SNAP2" ];then
       AND_SNAP2=" and p.SNAP_ID<=$SNAP2 "
       S_AND_SNAP2=" and s.SNAP_ID<=$SNAP2 "
   fi
fi
SQL="
  set line 190 pages 90
  col sql_id for a13
  col child_number for 999 head 'CHD|NBR'
  col sql_text for a60
  col ms for 999990.99 head 'ms|spent|per exec' justify c
  col Arows  for 99999999 head 'Actual|rows|per exec'
  col reads for 9999999 head 'reads|per exec'
  col plan_hash_value head 'plan'
  col execs head 'execs' for 99999999
  col gets head 'gets|per exec' for 99999999
  col ldate for a20 head 'Date'
break on ldate on report

with v as (
    select upper('$fobj') object_name from dual
    union
    select index_name from dba_indexes
where table_name=upper('$fobj') $AND_OWNER
 ) ,
v1 as    (
 select distinct
      p.sql_id, plan_hash_value
      from v, sys.wrh\$_sql_plan p
where  p.object_name=v.object_name $P_AND_OWNER $AND_SNAP1 $AND_SNAP2
) select
      to_char(begin_interval_time,'YYYY-MM-DD HH24:MI') ldate , v1.sql_id, v1.plan_hash_value
      ,nvl(s.EXECUTIONS_DELTA,0) execs
      ,nvl(s.ELAPSED_TIME_DELTA,0)       /decode(nvl(s.EXECUTIONS_DELTA,0),0,1,s.EXECUTIONS_DELTA)/1000 ms
      , nvl(s.ROWS_PROCESSED_DELTA,0)    /decode(nvl(s.EXECUTIONS_DELTA,0),0,1,s.EXECUTIONS_DELTA) arows
      , round(nvl(s.BUFFER_GETS_DELTA,0) /decode(nvl(s.EXECUTIONS_DELTA,0),0,1,s.EXECUTIONS_DELTA)) gets
      ,nvl(s.DISK_READS_DELTA,0)         /decode(nvl(s.EXECUTIONS_DELTA,0),0,1,s.EXECUTIONS_DELTA) reads
      ,substr(t.sql_text,1,60) sql_text
  from
        v1, sys.WRH\$_SQLSTAT s, sys.WRH\$_SQLTEXT t, DBA_HIST_SNAPSHOT ss
  where 
       v1.sql_id          = s.sql_id (+)
   and v1.plan_hash_value = s.PLAN_HASH_VALUE (+)
   and t.sql_id           = v1.sql_id
   and s.snap_id          = ss.snap_id $S_AND_SNAP1 $S_AND_SNAP2
order by to_char(begin_interval_time,'YYYY-MM-DD HH24:MI') desc, v1.sql_id 
/
"
# --------------------------------------------------------------------------
# List WRH and V$SQL_PLAN different plan for same slq_id
# --------------------------------------------------------------------------

elif [ "$METHOD" = "SHOW_PLAN" ];then
TITTLE="Show plan for $PLAN_HASH_VALUE"
if [ -n  "$SNAP1" ];then
   AND_SNAP_ID=" and snap_id = '$SNAP1' "
fi
if [ -n "$COMPACT" ];then
   SQL="COL id          FORMAT 999
COL parent_id   FORMAT 999 HEADING 'PARENT'
COL operation   FORMAT a75 heading 'Type of |Operations'
cOL object_name FORMAT a22
COL object_node FORMAT a16
COL ACCESS_PREDICATES FORMAT a35
   select snap_id, id ,  operation|| ' ' ||options operation, cost ,cardinality,
        search_columns,object_node,object_name
   from 
        sys.wrh\$_sql_plan
   where  
       PLAN_HASH_VALUE = '$PLAN_HASH_VALUE'  $AND_SNAP_ID and id=0
   order by snap_id;
"
else
   SQL="set feed off
set lines 210 pages 0 head on
COL id          FORMAT 999
COL operation   FORMAT a65 heading 'Type of |Operations'
COL object_node FORMAT a16
col snap_id for 99999 head 'Snap|id'
col parent for 999 head 'pid'
COL ACCESS_PREDICATES FORMAT a35
col PARTITION_START for a12 head 'Start'      
col PARTITION_STOP for a12 head 'Stop'      
col CPU_COST for 99999990 head 'cpu(k)'
col search_columns for 99999 head 'Index|Search|column'
col cardinality head 'Rows' for 999999999
col Cost for 99999999 head 'Cost'
col Object_name for a28 head 'Object'
col Object_node for a12 head 'Object|Node'
col sql_id noprint
break on snap_id skip 1 on sql_id on report

SELECT     sql_id,snap_id,id, parent_id parent, LPAD (' ', LEVEL - 1) || operation || ' ' ||
           options operation, 
           case 
                when id=0 then '( sqlid => '||sql_id||' )'
           else
               object_name
           end  object_name,
           cost ,cardinality, search_columns, cpu_cost/1000 cpu_cost,
           PARTITION_START, PARTITION_STOP, object_node
FROM       (
           SELECT sql_id,snap_id,time,id, parent_id, operation, options, cost, cardinality, CPU_COST,
                  search_columns, object_node,object_name, PARTITION_START, PARTITION_STOP
           FROM   sys.wrh\$_sql_plan
           WHERE  PLAN_HASH_VALUE = '$PLAN_HASH_VALUE'  $AND_SNAP_ID order by snap_id, sql_id)
START WITH id = 0
CONNECT BY PRIOR id = parent_id and prior snap_id = snap_id and prior sql_id = sql_id
/
select id, 'Access' , ACCESS_PREDICATES  from sys.wrh\$_sql_plan
           WHERE  PLAN_HASH_VALUE = '$PLAN_HASH_VALUE' and ACCESS_PREDICATES is not null $AND_SNAP_ID 
union 
select id, 'Filter', FILTER_PREDICATES from sys.wrh\$_sql_plan
           WHERE  PLAN_HASH_VALUE = '$PLAN_HASH_VALUE' and FILTER_PREDICATES is not null $AND_SNAP_ID
order by id
/

"
fi

# --------------------------------------------------------------------------
# List WRH and V$SQL_PLAN different plan for same slq_id
# --------------------------------------------------------------------------
elif [ "$METHOD" = "DIF_PLAN" ];then
if [ -n "$OWNER" ];then
   AND_OWNER=" and PARSING_SCHEMA_NAME = upper('$OWNER') "
fi
SQL="
col PARSING_SCHEMA_NAME format a18 head 'Parsed by'
col SQL_TEXT format a70
col OPV head 'Old plan|hash value' justify c
col NPV head 'New plan|hash value' justify c
select first_snap, a.sql_id, opv, npv, PARSING_SCHEMA_NAME,substr(vs.SQL_TEXT,1,70) sql_text
    from (
       select min(snap_id) first_snap ,ws.sql_id, ws.plan_hash_value opv,  s.plan_hash_value  npv,
              case
               when ws.plan_hash_value = s.plan_hash_value then 0
               when ws.plan_hash_value != s.plan_hash_value then 1
               else 2
              end  cpt_type
              from
                   sys.wrh\$_sql_plan ws,
                   (select sql_id,plan_hash_value from v\$sql_plan group by sql_id,plan_hash_value ) s
              where
                    ws.sql_id = s.sql_id
              group by ws.sql_id, ws.plan_hash_value, s.plan_hash_value
      ) a,
      v\$sql vs
      where cpt_type = 1 and vs.sql_id=a.sql_id $AND_OWNER 
     order by sql_id;
"
# --------------------------------------------------------------------------
#  Transfer an SQL PROFILE
# --------------------------------------------------------------------------
elif [ "$METHOD" = "TR_SQL_PROFILE" ];then
  if [ -z "$SO_SQL_ID" ];then
      echo 'No hinted source sql_id given'
      exit
  fi
  if [ -z "$STA_SQL_ID" ];then
      echo 'No target sql_id to modify access path given'
      exit
  fi
  if [ -z "$PLAN_HASH_VALUE" ];then
     echo "I need a plan value : -pv <plan hash value to set>"
     echo "It is the one used by -so <sql_id> "
     exit
  fi
SQL="
declare
    ar_profile_hints sys.sqlprof_attr;
    cl_sql_text clob;

  begin

   select extractvalue(value(d), '/hint') as outline_hints
          bulk collect into ar_profile_hints
   from xmltable('/*/outline_data/hint' passing (
           select xmltype(other_xml) as xmlval
           from dba_hist_sql_plan where sql_id = '$SO_SQL_ID' 
           and plan_hash_value=${PLAN_HASH_VALUE} and other_xml is not null)) d;

    select sql_text into cl_sql_text from dba_hist_sqltext  where  sql_id ='$STA_SQL_ID' and rownum=1 ;

   dbms_sqltune.import_sql_profile(
            sql_text     =>  cl_sql_text ,
            profile      =>  ar_profile_hints ,
            category     => '$CATEGORY',
            name         => 'PROFILE_$STA_SQL_ID',
            force_match  =>  true );
end;
/
"

echo "Doing:
$SQL
"


 
# --------------------------------------------------------------------------
#  Generate an SQL PROFILE
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SQL_PROFILE" ];then
  if [ -z "$SQL_ID" ];then
      echo 'No sql_id given'
      exit
  fi
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
  fi
  TASK=SQL_PRF_${SQL_ID}
  TASK_DESC="SQL profile $SQL_ID snap $SNAP1 --> $SNAP2"
  FOUT=$SBIN/tmp/sql_profile_${SNAP1}_${SNAP2}.txt
 SQL=" 
set linesize 132 pagesize 333 verify off head off feed off pause off trimspool on
set serveroutput on
DECLARE
            ret     varchar2(100);
BEGIN
  ret:=DBMS_SQLTUNE.CREATE_TUNING_TASK($SNAP1,$SNAP2,'$SQL_ID',null,DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,DBMS_SQLTUNE.TIME_LIMIT_DEFAULT, '$TASK', '$TASK_DESC' );
  DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || ret );
  DBMS_SQLTUNE.execute_tuning_task(task_name => '$TASK');

END;
/
SET LONG 10000;
SET PAGESIZE 1000
SET LINESIZE 190
SELECT DBMS_SQLTUNE.report_tuning_task('$TASK') AS recommendations FROM dual;
"
# --------------------------------------------------------------------------
# Run the Database advisor
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_ADV" ];then
  TASK=ADDM_TASK_$$
  FOUT=$SBIN/tmp/aw_addm_task_`date +%Y%m%d%H%M`.txt
  if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
fi

SQL="
set linesize 132 pagesize 333 verify off head off feed off pause off trimspool on
DECLARE
            task_name VARCHAR2(30) := '$TASK';
            task_desc VARCHAR2(30) := 'ADDM snap $SNAP1 --> $SNAP2';
            task_id NUMBER;
            v_dbid number;
            v_inst number;
BEGIN

         dbms_advisor.create_task('ADDM', task_id, task_name, task_desc, null);
         dbms_advisor.set_task_parameter('$TASK', 'START_SNAPSHOT', $SNAP1);
         dbms_advisor.set_task_parameter('$TASK', 'END_SNAPSHOT', $SNAP2);
         dbms_advisor.set_task_parameter('$TASK', 'INSTANCE', v_inst);
         dbms_advisor.set_task_parameter('$TASK', 'DB_ID', v_dbid);
         dbms_advisor.execute_task('$TASK');
END;
/
SET LONG 1000000 PAGESIZE 0 LONGCHUNKSIZE 1000
COLUMN get_clob FORMAT a132
SELECT dbms_advisor.get_task_report('$TASK', 'TEXT', 'ALL') FROM   sys.dual;
"
do_sql
# --------------------------------------------------------------------------
# Run the AWR sql tuning advisor
# --------------------------------------------------------------------------
elif [ "$METHOD" = "SQL_TUNE" ];then
#  this  is just a wrapper on rdbms/admin/sqlrprt.sql for ease of use
TASK=SQL_${SQL_ID}_$$

SQL="
set serveroutput on 
variable task_name varchar2(64);
set linesize 132 feed off
DECLARE
  cnt      NUMBER;
  bid      NUMBER;
  eid      NUMBER;
  report   varchar2(32000);
BEGIN
  -- If it's not in V$SQL we will have to query the workload repository
  select count(*) into cnt from V\$SQLSTATS where sql_id = '$SQL_ID';

  IF (cnt > 0) THEN
    :task_name := dbms_sqltune.create_tuning_task(sql_id => '$SQL_ID', task_name=>'$TASK');
  ELSE
    select min(snap_id) into bid from   dba_hist_sqlstat where  sql_id = '$SQL_ID';
    select max(snap_id) into eid from   dba_hist_sqlstat where  sql_id = '$SQL_ID'; 
    :task_name := dbms_sqltune.create_tuning_task(begin_snap => bid, end_snap => eid, sql_id => '$SQL_ID', task_name=>'$TASK');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF (SQLCODE = -13780) THEN
      dbms_output.put_line ('ERROR: statement is not in the cursor cache ' ||
                            'or the workload repository.');
      dbms_output.put_line('Execute the statement and try again');
    ELSE
      RAISE;
    END IF;
END;
/
set heading off
set long 300000  longchunksize 1000  linesize 132
prompt executing taks $TASK
exec dbms_sqltune.execute_tuning_task('$TASK');
prompt reporting taks $TASK
select dbms_sqltune.report_tuning_task('$TASK') from dual ;
prompt drop taks $TASK
exec  dbms_sqltune.drop_tuning_task('$TASK');
"
# --------------------------------------------------------------------------
#  List AWR sql load between snap_id single out each snap
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SQL_LOAD_EACH" ];then
  if [ -z "$SNAP1" ];then
      echo "I need a -b <snap_id>"
      exit
  fi
  if [ -z "$SNAP2" ];then
      echo "I need a -e <snap_id>"
      exit
  fi
  if [ "$REP_TYPE" = "DEFAULT" ];then
      TITTLE="Most expensive SQL in the workload repository"
      FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
      FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot,BUFFER_GETS_tot,WAIT_tot,"
      ORDER_CLAUSE="$F_INST_NUM elapsed"
  elif [ "$REP_TYPE" = "DISK_READS" ];then
      TITTLE="Most disk reads SQL in the workload repository"
      FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
      FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot,BUFFER_GETS_tot,WAIT_tot,"
      ORDER_CLAUSE="$F_INST_NUM DISK_READS_tot"
  elif [ "$REP_TYPE" = "DISK_WRITES" ];then
      TITTLE="Most disk write SQL in the workload repository"
      FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, 
          sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.PHYSICAL_WRITE_REQUESTS_DELTA)DISK_WRITES_tot,
          sum(stat.DIRECT_WRITES_DELTA)DIRECT_WRITES_tot,
          round(sum(stat.PHYSICAL_WRITE_BYTES_DELTA)/1024/1024,0) PHYSICAL_WRITES_bytes_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
      FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot, DISK_WRITES_tot, DIRECT_WRITES_tot, PHYSICAL_WRITES_bytes_tot,BUFFER_GETS_tot,WAIT_tot,"
      ORDER_CLAUSE="$F_INST_NUM DISK_WRITES_tot"
   elif [ "$REP_TYPE" = "ROWS" ];then
      TITTLE="Most expensive SQL / rows per execution"
      FIELDS="PARSING_SCHEMA_NAME, Execs, ROWS_PROCESSED, FETCHES, END_OF_FETCH_COUNT, ELAPSED_TIME elapsed_x,"
      ORDER_CLAUSE="$F_INST_NUM rows_processed "
      FIELDS_FIGURES="PARSING_SCHEMA_NAME,
          sum(stat.EXECUTIONS_DELTA) execs, 
          sum(round(stat.ROWS_PROCESSED_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))ROWS_PROCESSED,
          sum(round(stat.FETCHES_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))FETCHES,
          sum(round(stat.END_OF_FETCH_COUNT_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))END_OF_FETCH_COUNT,
          sum(round(stat.ELAPSED_TIME_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))/1000000)ELAPSED_TIME,"
   elif [ "$REP_TYPE" = "EXECS" ];then
        TITTLE="Most expensive SQL / per execution"
        FIELDS_FIGURES="PARSING_SCHEMA_NAME,
          sum(stat.EXECUTIONS_DELTA) execs, 
          sum(stat.DISK_READS_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))DISK_READS,
          sum(stat.BUFFER_GETS_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))BUFFER_GETS,
          sum(elapsed_time_delta/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)) / 1000000 as elapsed_x,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))/1000000 waits,"
        FIELDS="PARSING_SCHEMA_NAME,elapsed_x, Execs, DISK_READS,BUFFER_GETS,WAITS,"
        ORDER_CLAUSE="$F_INST_NUM elapsed_x"
   else
        FIELDS_FIGURES="sum(elapsed_time_delta) / 1000000 as elapsed,
        sum(IOWAIT_DELTA) / 1000000 as iowait,
        sum(CLWAIT_DELTA) / 1000000 as clwait,
        sum(APWAIT_DELTA) / 1000000 as apwait,
        sum(CCWAIT_DELTA) / 1000000 as CCWAIT,
        sum(CCWAIT_DELTA+IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA) / 1000000 as totwait,"
    FIELDS="elapsed,totwait,iowait,clwait,apwait,CCWAIT,"
    ORDER_CLAUSE="$F_INST_NUM totwait"
   fi
   if [ -n "$OWNER" ];then
          AND_OWNER=" and parsing_schema_name = upper('$OWNER') "
   fi
  FOUT=aw_sl_${SNAP1}_to_${SNAP2}.txt 
  echo $TITTLE > $FOUT
  cpt=$SNAP1
  LEN_TEXT=${LEN_TEXT:-55}
  while true
  do
    sqlplus -s "$CONNECT_STRING"  >>$FOUT  2>&1 <<EOF
set lines 190 pages 66
col elapsed format 999,999,990.90 head 'Total execution|Time (sec)'
col elapsed_x format 999,990.9000 head 'Elapse per|exec (sec)'
col sql_text_fragment format a55
col EXECUTIONS_TOT head 'Total|Executions' justify c
col DISK_READS_tot head 'Total|Disk reads' justify c
col DIRECT_WRITES_TOT head 'Total|Direct Writes' justify c
col DISK_WRITES_TOT head 'Total|Disk Writes' justify c
col PHYSICAL_WRITES_bytes_tot head 'Disk| Writes(meg)' justify c
col BUFFER_GETS_TOT head 'Total|Buffer gets' justify c
col WAIT_tot head 'IO Wait' justify c form 99990.99
col APWAIT format 99999990.99 head 'Application|Wait' justify c
col IOWAIT format 99999990.99 head 'IO|Wait' justify c
col CLWAIT format 99999990.99 head 'cluster|Wait' justify c
col CCWAIT format 99999990.99 head 'Concurrency|Wait' justify c
col totwait format 99999990.99 head 'total|Wait' justify c
col Username for a22
col PARSING_SCHEMA_NAME format a20 head 'Username'
col END_OF_FETCH_COUNT for 99999 head 'End of|Fetch|count' justify c
col FETCHES for 99999 head 'Fetch' justify c
col rows_processed for 999999999 head 'Rows|Processed' justify l
col disk_reads for 9999990.9
col buffer_gets for 9999990.9
set linesize 190 pagesize 66
variable newl varchar2(64);
col execs head 'Execs'
$PROMPT
set feed off
set head off
select 'Snap: ' , s.snap_id, ' From : ' ,
      to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')    , ' To : ',
      to_char(END_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')   
  from sys.wrm\$_snapshot s
  where s.instance_number = $INST_NUM and s.dbid=$DBID and s.snap_id=$SNAP1
/
set head on
set termout on
select $F_INST_NUM sql_id, $FIELDS
        sql_text_fragment 
  from ( select $F_INST_NUM 
     stat.sql_id as sql_id, $FIELDS_FIGURES
     (select to_char(substr(replace(replace(st.sql_text,chr(10),' '),chr(13),' '),1,55))
             from dba_hist_sqltext st where st.dbid = stat.dbid and st.sql_id = stat.sql_id) as sql_text_fragment
 from 
     dba_hist_sqlstat stat, 
     dba_hist_sqltext text
 where stat.sql_id = text.sql_id 
   and stat.dbid   = text.dbid and snap_id = $SNAP1 $AND_STAT_DBID $AND_INST_NUM $AND_OWNER
 group by stat.dbid, $F_INST_NUM stat.sql_id,PARSING_SCHEMA_NAME
 order by $ORDER_CLAUSE desc
) where ROWNUM <= $ROWNUM ;
EOF
    SNAP1=`expr $SNAP1 + 1 `
    if [ $SNAP1 -gt $SNAP2 ];then
         break
    fi
  done 
exit
# --------------------------------------------------------------------------
#  List AWR sql load between snap_id
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SQL_LOAD" ];then
if [ "$LAST_SNAP" = "TRUE" ];then
       VAR=`get_last_snap`
       VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
       SNAP1=`echo $VVAR | cut -f1 -d' '`
fi
if [ -n "$SNAP1" ];then
    SNAP_START=$SNAP1
    if [ -z "$SNAP2" ];then
       SNAP_END=$SNAP1
    else
       SNAP_END=$SNAP2
    fi
fi
if [ -n "$SNAP_START" ];then
    AND_SNAP1=" and stat.SNAP_ID>=$SNAP_START"
    F_ST=`get_snap_start $SNAP_START`
    PROMPT="prompt measurement starting from snap_id $SNAP_START at $F_ST"
fi
if [ -n "$SNAP_END" ];then
   AND_SNAP2=" and stat.SNAP_ID<=$SNAP_END "
   F_ST=`get_snap_start $SNAP_END`
   PROMPT="$PROMPT and stop at $SNAP_END included ($F_ST)"
fi
if [ "$REP_TYPE" = "DEFAULT" ];then
    TITTLE="Most expensive SQL in the workload repository"
    FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
    FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot,BUFFER_GETS_tot,WAIT_tot,"
    ORDER_CLAUSE="$F_INST_NUM elapsed"
elif [ "$REP_TYPE" = "DISK_READS" ];then
      TITTLE="Most disk reads SQL in the workload repository"
      FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
      FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot,BUFFER_GETS_tot,WAIT_tot,"
      ORDER_CLAUSE="$F_INST_NUM DISK_READS_tot"
elif [ "$REP_TYPE" = "DISK_WRITES" ];then
      TITTLE="Most disk write SQL in the workload repository"
      FIELDS_FIGURES="PARSING_SCHEMA_NAME, 
          sum(stat.EXECUTIONS_DELTA) EXECUTIONS_tot, 
          sum(stat.DISK_READS_DELTA)DISK_READS_tot,
          sum(stat.PHYSICAL_WRITE_REQUESTS_DELTA)DISK_WRITES_tot,
          sum(stat.DIRECT_WRITES_DELTA)DIRECT_WRITES_tot,
          round(sum(stat.PHYSICAL_WRITE_BYTES_DELTA)/1024/1024,0) PHYSICAL_WRITES_bytes_tot,
          sum(stat.BUFFER_GETS_DELTA)BUFFER_GETS_TOT,
          sum(elapsed_time_delta) / 1000000 as elapsed,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA)/1000000 WAIT_tot,"
      FIELDS="PARSING_SCHEMA_NAME,elapsed, EXECUTIONS_TOT, DISK_READS_tot, DISK_WRITES_tot, DIRECT_WRITES_tot , PHYSICAL_WRITES_bytes_tot, BUFFER_GETS_tot,WAIT_tot,"
      ORDER_CLAUSE="$F_INST_NUM DISK_WRITES_tot"
elif [ "$REP_TYPE" = "ROWS" ];then

    TITTLE="Most expensive SQL / rows per execution"
    FIELDS="PARSING_SCHEMA_NAME, Execs, ROWS_PROCESSED, FETCHES, END_OF_FETCH_COUNT, ELAPSED_TIME elapsed_x,"
    ORDER_CLAUSE="$F_INST_NUM rows_processed "
    FIELDS_FIGURES="PARSING_SCHEMA_NAME,
          sum(stat.EXECUTIONS_DELTA) execs, 
          sum(round(stat.ROWS_PROCESSED_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))ROWS_PROCESSED,
          sum(round(stat.FETCHES_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))FETCHES,
          sum(round(stat.END_OF_FETCH_COUNT_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)))END_OF_FETCH_COUNT,
          sum(round(stat.ELAPSED_TIME_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))/1000000)ELAPSED_TIME,"

elif [ "$REP_TYPE" = "EXECS" ];then
    TITTLE="Most expensive SQL / per execution"
    FIELDS_FIGURES="PARSING_SCHEMA_NAME,
          sum(stat.EXECUTIONS_DELTA) execs, 
          sum(stat.DISK_READS_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))DISK_READS,
          sum(stat.BUFFER_GETS_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))BUFFER_GETS,
          sum(elapsed_time_delta/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA)) / 1000000 as elapsed_x,
          sum(IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA+CCWAIT_DELTA/decode(stat.EXECUTIONS_DELTA,0,1,stat.EXECUTIONS_DELTA))/1000000 waits,"
    FIELDS="PARSING_SCHEMA_NAME,elapsed_x, Execs, DISK_READS,BUFFER_GETS,WAITS,"
    ORDER_CLAUSE="$F_INST_NUM elapsed_x"
else
    FIELDS_FIGURES="sum(elapsed_time_delta) / 1000000 as elapsed,
        sum(IOWAIT_DELTA) / 1000000 as iowait,
        sum(CLWAIT_DELTA) / 1000000 as clwait,
        sum(APWAIT_DELTA) / 1000000 as apwait,
        sum(CCWAIT_DELTA) / 1000000 as CCWAIT,
        sum(CCWAIT_DELTA+IOWAIT_DELTA+CLWAIT_DELTA+APWAIT_DELTA) / 1000000 as totwait,"
    FIELDS="elapsed,totwait,iowait,clwait,apwait,CCWAIT,"
    ORDER_CLAUSE="$F_INST_NUM totwait"

fi
   if [ -n "$OWNER" ];then
          AND_OWNER=" and parsing_schema_name = upper('$OWNER') "
   fi
LEN_TEXT=${LEN_TEXT:-55}
SQL="
col elapsed format 999,999,990.90 head 'Total execution|Time (sec)'
col elapsed_x format 999,990.9000 head 'Elapse per|exec (sec)'
col sql_text_fragment format a$LEN_TEXT
col EXECUTIONS_TOT head 'Total|Executions' justify c
col DISK_READS_tot head 'Total|Disk reads' justify c
col BUFFER_GETS_TOT head 'Total|Buffer gets' justify c
col WAIT_tot head 'IO Wait' justify c form 99990.99
col APWAIT format 99999990.99 head 'Application|Wait' justify c
col PHYSICAL_WRITES_bytes_tot head 'Disk| Writes(meg)' justify c
col IOWAIT format 99999990.99 head 'IO|Wait' justify c
col CLWAIT format 99999990.99 head 'cluster|Wait' justify c
col CCWAIT format 99999990.99 head 'Concurrency|Wait' justify c
col totwait format 99999990.99 head 'total|Wait' justify c
col DIRECT_WRITES_TOT head 'Total|Direct Writes' justify c
col DISK_WRITES_TOT head 'Total|Disk Writes' justify c
col PARSING_SCHEMA_NAME format a20 head 'Username'
col END_OF_FETCH_COUNT for 99999 head 'End of|Fetch|count' justify c
col FETCHES for 99999 head 'Fetch' justify c
col rows_processed for 999999999 head 'Rows|Processed' justify l
col disk_reads for 9999990.9
col buffer_gets for 9999990.9
set linesize 190 pagesize 66
variable newl varchar2(64);
col execs head 'Execs'
$PROMPT
prompt Use st -i <sql_id> to see full text
set feed off
prompt 

set termout on
select $F_INST_NUM sql_id, $FIELDS
        sql_text_fragment 
  from ( select $F_INST_NUM 
     stat.sql_id as sql_id, $FIELDS_FIGURES
     (select to_char(substr(replace(replace(st.sql_text,chr(10),' '),chr(13),' '),1,$LEN_TEXT))
             from dba_hist_sqltext st where st.dbid = stat.dbid and st.sql_id = stat.sql_id) as sql_text_fragment
 from 
     dba_hist_sqlstat stat, 
     dba_hist_sqltext text
 where stat.sql_id = text.sql_id 
   and stat.dbid   = text.dbid $AND_SNAP1 $AND_SNAP2 $AND_STAT_DBID $AND_INST_NUM $AND_OWNER
 group by stat.dbid, $F_INST_NUM stat.sql_id,PARSING_SCHEMA_NAME
 order by $ORDER_CLAUSE desc
) where ROWNUM <= $ROWNUM ;
"
# --------------------------------------------------------------------------
# Show AWR retention
# --------------------------------------------------------------------------
elif [ "$METHOD" = "RET" ];then
TITTLE="Retention Period for AWR repository"
SQL="
col a1 head 'Snapshot Interval| (minutes)' justify c
col a2 head 'Retention |(in minutes)' justify c
col a3 head 'Retention |(in days)' justify c
select a1,a2,a2/1440 a3 from (
 select
      extract( day from snap_interval) *24*60+
      extract( hour from snap_interval) *60+
      extract( minute from snap_interval ) a1,
      extract( day from retention) *24*60+
      extract( hour from retention) *60+
      extract( minute from retention ) a2
from dba_hist_wr_control);
"
# --------------------------------------------------------------------------
# Set AWR retention
# --------------------------------------------------------------------------
elif [ "$METHOD" = "SET" ];then
   if [ -z "$DURATION" ];then
         echo "No duration in minutes given"
         exit
   fi
   if [ -z "$INT_MINUTES" ];then
         echo "No interval in minutes given"
         exit
   fi
SQL="exec DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS($DURATION,$INT_MINUTES) ;"
echo "--> $SQL"
# --------------------------------------------------------------------------
# execute ash report
# --------------------------------------------------------------------------
elif [ "$METHOD" = "ASH" ];then

if [ -z "$SID" ];then
      REP_SID=ALL
else 
      REP_SID=$SID
      VAR_SID=",0,0,$SID"
fi
if [ "$AWR_OUTPUT_TYPE" = "text" ];then
    fn_name=ASH_REPORT_TEXT
    FOUT=$SBIN/tmp/ash_${REP_SID}_${ORACLE_SID}.txt
else
    fn_name=ASH_REPORT_HTML
    FOUT=$SBIN/tmp/ash_${REP_SID}_${ORACLE_SID}.html
fi
if [ -z "MIN" ];then
     MIN=30
fi
DATE1="SYSDATE-30/1440"
DATE2="SYSDATE-1/1440"
   #cat  <<EOF
SQL="
column inst_num   new_value inst_num  
column dbid       new_value dbid ;
column logon_time new_value logon_time  noprint ;
column now_t      new_value now_t noprint ;
set linesize 132 pagesize 333 verify off head off feed off pause off 
select logon_time,sysdate now_t from v\$session where sid = '$SID';

set lines 130
select * from table(dbms_workload_repository.$fn_name(  $DBID, $INST_NUM, $DATE1, $DATE2 $VAR_SID));
"
do_sql
exit
# --------------------------------------------------------------------------
# 
# --------------------------------------------------------------------------
# view outlines and plan for one sqlid
# --------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_SQL_ID" ];then
   # --------------------------------------------------------------------------
   # Author  : Randolf Geist at http://oracle-randolf.blogspot.com/2009/03/plan-stability-in-10g-using-existing.html
   # Adapted to Smenu by bpa
   # --------------------------------------------------------------------------
   if [ -n "$CR_SQL_PROFILE" ];then
     if [  -z "$SQL_ID"   ];then
          echo "I need the target SQL ID"
          exit
     fi
     if [  -z "$SOURCE_SQL_ID"   ];then
          echo "I need the SOURCE, hinted SQL ID"
          exit
     fi
     if [ -z "$V_PLAN_HASH_VALUE" ];then
            echo "Please provide an plan_hash_value as new plan for SQL_ID $SQL_ID"
            echo "Use: \"aw -s <SQL_ID> -ot\"   to check the available plans"
            exit
     fi 
     SQL="
set lines 210 pages 0 chunksize 1000
declare
      ar_profile_hints sys.sqlprof_attr;  
      cl_sql_text      clob;
      sqlcmd           varchar2(4000);
      cpt              number ;
begin
     select distinct count(plan_hash_value) into cpt from dba_hist_sql_plan where sql_id = '$SOURCE_SQL_ID' ;
     if cpt = 1 then
        sqlcmd:=q'{
        select  extractvalue(value(d), '/hint') as outline_hints  
                   from  xmltable('/*/outline_data/hint' passing
                    ( select xmltype(other_xml) as xmlval
                                    from
                                         dba_hist_sql_plan
                                    where
                                         sql_id = '$SOURCE_SQL_ID' 
                                    and  other_xml is not null
                            )
                     ) d }';
     else
        sqlcmd:=q'{
        select  extractvalue(value(d), '/hint') as outline_hints  
                   from  xmltable('/*/outline_data/hint' passing
                    ( select xmltype(other_xml) as xmlval
                                    from
                                         dba_hist_sql_plan
                                    where
                                         sql_id = '$SOURCE_SQL_ID' 
                                    and  plan_hash_value = $V_PLAN_HASH_VALUE
                                    and  other_xml is not null
                     )
                     ) d }';
     end if;
     begin
        execute immediate sqlcmd bulk collect  into ar_profile_hints ;
     exception
       when others then
           dbms_output.put_line('Error in execution (did you miss the plan_hash_value?) ' ||chr(10) || sqlcmd ) ;
     end ;
    
     select sql_text  into cl_sql_text  from dba_hist_sqltext  where sql_id = '$SQL_ID';  
     dbms_sqltune.import_sql_profile(    sql_text     => cl_sql_text, 
                                         profile      => ar_profile_hints, 
                                         category     => '$CATEGORY'  , 
                                         name         => 'profile_$SQL_ID'  ,
                                         force_match  => true  );     
end;
/
"
    # --------------------------------------------------------------------------
    # View outlines 
    # --------------------------------------------------------------------------
    elif [ -n "$AW_OUTLINES"   ];then
         if [ -n "$V_PLAN_HASH_VALUE" ];then
            AND_PLAN_HASH_VALUE=" and plan_hash_value = $V_PLAN_HASH_VALUE "
         fi 
         EXECUTE=YES
         SQL="set linesize 250 pagesize 333 verify off head off feed off pause off 
set serveroutput on 
          variable id_plan number ;
          declare
             v_id_plan   number ;
             v_cpt_plan  number ;
          begin
          select min(plan_hash_value) , count(1) into v_id_plan , v_cpt_plan
                  from dba_hist_sql_plan where sql_id='$SQL_ID' and id = 0 $AND_PLAN_HASH_VALUE;
          dbms_output.put_line( ' number of plans : ' || to_char(v_cpt_plan)  || ' First :' || to_char(v_id_plan) );
          if  v_cpt_plan > 1 then
              dbms_output.put_line('List of all plan_hash_value:');
              for c in (select plan_hash_value from dba_hist_sql_plan where sql_id='$SQL_ID' and id = 0 )
              loop
                  dbms_output.put_line('.       '||to_char(c.plan_hash_value) );
              end loop;
          end if;
          :id_plan:=v_id_plan ;
          end ;
/
prompt
select  extractvalue(value(d), '/hint') as outline_hints  
                   from  xmltable('/*/outline_data/hint' passing 
                    ( select xmltype(other_xml) as xmlval 
                                    from 
                                         dba_hist_sql_plan 
                                    where 
                                         sql_id = '$SQL_ID'  
                                    and  plan_hash_value = :id_plan
                                    and  other_xml is not null   
                            )          
                     ) d
/
"
do_sql
    # --------------------------------------------------------------------------
    #  Extract the SQL plan (aw -s)
    # --------------------------------------------------------------------------
     else # We want to extract the sql plan and info
       if [ -n "$SNAP1" ];then
          if [ -z "$SNAP2" ];then
           var=` get_last_snap'`
           if [ ! $SNAP1  -eq $var ];then
              # we cannot call the function with same argument, so we remove 1 to SNAP1 
              # otherwise we get next SNAP1
              SNAP2=$SNAP1
              SNAP1=`expr $SNAP1 - 1`
           else
              # we are the last snap 
              SNAP2=$var
              SNAP1=`expr $SNAP1 - 1`
           fi
        fi
       fi

        if [ -z "$SNAP1" ];then
            VAR=`get_snap_beg_end`
            VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
            SNAP1=`echo $VVAR | cut -f1 -d' '`
            SNAP2=`echo $VVAR | cut -f2 -d' '`
        elif [ -z "$SNAP2" ];then
            echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
            SNAP2=`expr $SNAP1 + 1`
            echo "Using default -b <nn> + 1> --> $SNAP2"
        fi 
        # at this stage, we have a value for BEG snap and END snap
        if [ "$AWR_OUTPUT_TYPE" = "text" ];then
             fn_name=awr_sql_report_text
             FOUT=$SBIN/tmp/sql_sid_${SQL_ID}_${ORACLE_SID}_${SNAP1}_${SNAP2}.txt
        else
             fn_name=awr_sql_report_html
             FOUT=$SBIN/tmp/sql_sid_${SQL_ID}_${ORACLE_SID}_${SNAP1}_${SNAP2}.html
        fi

#set linesize 132 pagesize 333 verify off head off feed off pause off 
SQL="
set pages 0 lines 159
select output from table(dbms_workload_repository.$fn_name( $DBID, $INST_NUM, $SNAP1, $SNAP2, '$SQL_ID', 8 ));
"
#EOF
do_sql
        if [ "$AWR_OUTPUT_TYPE" = "text" ];then
            if [ -f $FOUT ];then
               if $SBINS/yesno.sh "to review the report now " DO Y
                   then
                      vi $FOUT
               fi
            else
                echo " Error : I did not found the report file $FOUT! "
            fi
        else
            if [ -f $FOUT ];then
                  echo "Report done :"
                  ls -l $FOUT
            else
                   echo " Error : I did not found the report file $FOUT! "
            fi
        fi
        exit
     fi
exit
# --------------------------------------------------------------------------
# execute one snap
# --------------------------------------------------------------------------
elif [ "$METHOD" = "GET_SNAP" ];then
     echo "Doing : execute dbms_workload_repository.create_snapshot"
     SQL="execute dbms_workload_repository.create_snapshot ;"
elif [ "$METHOD" = "SHOW_KEEP_FTS" ];then
  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f1 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
fi


SQL="prompt The 'K' indicates that the table is in the KEEP Pool.'
select 
   to_char(sn.end_interval_time,'mm/dd/rr hh24') time,
   p.owner, 
   p.name, 
   t.num_rows,
   decode(t.buffer_pool,'KEEP','Y','DEFAULT','N') K,
   s.blocks blocks,
   sum(a.executions_delta) nbr_FTS
from 
   dba_tables   t,
   dba_segments s,
   dba_hist_sqlstat    a,
   dba_hist_snapshot sn,
   (select distinct 
     pl.sql_id,
     object_owner owner, 
     object_name name
   from 
      dba_hist_sql_plan pl
   where 
      operation = 'TABLE ACCESS'
      and
      options = 'FULL') p
where
        a.snap_id = sn.snap_id 
   and  a.sql_id = p.sql_id
   and t.owner = s.owner
   and t.table_name = s.segment_name
   and t.table_name = p.name
   and t.owner = p.owner
   and t.owner not in ('SYS','SYSTEM') and sn.snap_id >= $SNAP1 and sn.snap_id <= $SNAP2
having
   sum(a.executions_delta) > 1
group by 
   to_char(sn.end_interval_time,'mm/dd/rr hh24'),p.owner, p.name, t.num_rows, t.cache, t.buffer_pool, s.blocks
order by 1 asc;
"
# -----------------------------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_DIF_REPORT" ];then

if [ -z "$SNAP1" ];then
    VAR0=`get_snap_beg_end`
    VVAR=`echo $VAR0 | sed '/^$/d' |  cut -f1 -d':'`
    VAR=`echo $VVAR | cut -f1 -d' '`         # we take the last 2 and substract 1 for each value to leave room for the next 2
    SNAP1=`expr $VAR - 1`
    SNAP2=`expr $VAR `
    SNAP3=`expr $VAR `
    SNAP4=`expr $VAR + 1`
elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
fi
if [ -z "$SNAP3" ];then
      SNAP3=$SNAP2
fi
if [ -z "$SNAP4" ];then
      SNAP4=`expr $SNAP3 + 1`
fi
# at this stage, we have a value for BEG snap and END snap
if [ "$AWR_OUTPUT_TYPE" = "text" ];then
    FOUT=$SBIN/tmp/awr_diff_report_${ORACLE_SID}_${SNAP1}_${SNAP3}.txt
    fn_name=AWR_DIFF_REPORT_TEXT
else
    FOUT=$SBIN/tmp/awr_diff_report_${ORACLE_SID}_${SNAP1}_${SNAP3}.html
    fn_name=AWR_DIFF_REPORT_HTML 
fi

unset SHEAD

SQL="
set linesize 1500 pagesize 0 verify off head off feed off pause off trimspool on

select output from table(dbms_workload_repository.$fn_name( $DBID, $INST_NUM, $SNAP1, $SNAP2, $DBID, $INST_NUM, $SNAP3, $SNAP4 ));
"
do_sql
if [ -f $FOUT ];then
    if $SBINS/yesno.sh "to review the report now " DO Y
        then
          vi $FOUT
    fi
else
   echo " Error : did not find the report $FOUT"
fi
exit

# -----------------------------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_REPORT" ];then

  if [ -n "$SNAP1" ];then
        if [ -z "$SNAP2" ];then
           var=` get_last_snap'`
           if [ ! $SNAP1  -eq $var ];then
              SNAP2=`expr $SNAP1 + 1`
           else
              SNAP2=$var
              SNAP1=`expr $SNAP1 - 1`
           fi
        fi
   fi


if [ -z "$SNAP1" ];then
    VAR=`get_snap_beg_end`
    VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
    SNAP1=`echo $VVAR | cut -f1 -d' '`
    SNAP2=`echo $VVAR | cut -f2 -d' '`
elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
fi 
# at this stage, we have a value for BEG snap and END snap
if [ "$AWR_OUTPUT_TYPE" = "text" ];then
    FOUT=$SBIN/tmp/awr_report_${ORACLE_SID}_${SNAP1}_${SNAP2}.txt
    fn_name=AWR_REPORT_TEXT
else
    FOUT=$SBIN/tmp/awr_report_${ORACLE_SID}_${SNAP1}_${SNAP2}.html
    fn_name=AWR_REPORT_HTML
fi

SQL="
set linesize 190 pagesize 333 verify off head off feed off pause off  trimspool on
select output from table(dbms_workload_repository.$fn_name( $DBID, $INST_NUM, $SNAP1, $SNAP2,  8 ));
"
do_sql

#if [ -f $FOUT ];then
#    if $SBINS/yesno.sh "to review the report now " DO Y
#        then
#          vi $FOUT
#    fi
#else
#   echo " Error : did not find the report $FOUT"
#fi
# -----------------------------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_BASELINE" ];then
SQL="
col BASELINE_NAME format a30
select BASELINE_ID,BASELINE_NAME, START_SNAP_ID, START_SNAP_TIME, END_SNAP_ID, END_SNAP_TIME
  from (
select BASELINE_ID,BASELINE_NAME, START_SNAP_ID, to_char(START_SNAP_TIME,'YYYY-MM-DD HH24:MI:SS')START_SNAP_TIME, 
       END_SNAP_ID, to_char(END_SNAP_TIME,'YYYY-MM-DD HH24:MI:SS')END_SNAP_TIME
       from dba_hist_baseline
) where rownum<=$ROWNUM;
"
# -----------------------------------------------------------------------------------------------
elif [ "$METHOD" = "LIST_SNAP" ];then
if [ -n "$SNAP1" ];then
   AND_SNAP1=" and s.snap_id = $SNAP1"
fi
SQL="

prompt
prompt
prompt Snapshots for $ORACLE_SID  instance : $INST_NUM
prompt ==========================================
prompt

select $DBID_F snap_id
     , snap_level            
     , to_char(BEGIN_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')    snap_begin
     , to_char(END_INTERVAL_TIME,' dd Mon YYYY HH24:mi:ss')    snap_end 
  from (
select $S_DBID s.snap_id
     , s.snap_level
     , s.BEGIN_INTERVAL_TIME
     , s.END_INTERVAL_TIME
  from sys.wrm\$_snapshot s
  where s.instance_number   = $INST_NUM and s.dbid=$DBID $AND_SNAP1
  order by   snap_id desc 
) where rownum <=$ROWNUM
/
"
# -----------------------------------------------------------------------------------------------
elif [ "$METHOD" = "AWR_USE" ];then
SQL="select NAME, DETECTED_USAGES, to_char(LAST_USAGE_DATE,'DD-MM-YYYY HH24:MI:SS') last_usage, 
     DESCRIPTION from SYS.DBA_FEATURE_USAGE_STATISTICS where DETECTED_USAGES > 0 and name in ('Automatic Database Diagnostic Monitor',
'Automatic Workload Repository','Segment Advisor','SQL Tuning Advisor');"

fi

# ................................
# we do the job here
# ................................
do_sql
