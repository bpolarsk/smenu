#!/bin/ksh 
# program : smenu_metric.ksh
# author  : B. Polarski
# date    : 01 June 2009
# set -x
# ---------------------------------------------------------------------------
function help
{
cat <<EOF
 

            Show System metrics

             met:
                met -l                             : Show current system metrics (as of now)
                met -l2                            : Show current system metrics (as of now) only for type=2
                met -l -b <snap_id> [-e <snap>]    : System metrics for a given period (out of AWR)
                met -l -i <id> -b <snap_id> [-e <snap>] : System metrics for a given period (out of AWR)

                met -s                             : Metrics summary (data for the last hour)
                met -s2                            : Metrics summary (data for the last hour) only for type=2
                met -r2                            : Metrics summary for last 20 snapis, type=2 for read, commit, rollback
                met -s -b <snap_id> [-e <snap>]    : Metric summary for a given period (out of AWR)
                met -f                             : show current system load
                met -f2                            : show system load for the last 13 snaps
              

       Note : 
              -v      : Verbose
              -b      : begin snap_id
              -e      : end   snap_id. If you mention -e <snap_id>, the last snap_id is included
              -i <id> : restrict show to statistics id. 

                ie :   met -l -i 2121  -b 1750 -e 1765 : show executions per seconds during 16 snaps

               if -e <snap_id> is not given, it defaults to -b <snap_id> + 1, excluded
 
                ie  :  if you ommit -e <snap_id>, this is how it is translated:

                   met -l -b 1750           --> snap_id >= 1750 and snap_id < 1751

                      if you provide -e <snap_id>, this is how it is translated:

                   met -l -b 1750 -e 1760   --> snap_id >= 1750 and snap_id <= 1760

EOF
exit
}
# ---------------------------------------------------------------------------
function get_range_snap
{
    ret=`sqlplus -s "$CONNECT_STRING"  <<EOF
set head off verify off feed off pause off
column instance_number   new_value instance_number  noprint
col beg_id new_value beg_id
col end_id new_value end_id

with v as ( select instance_number inst from   v\\$instance )
,v2 as ( select dbid from v\\$database )
select min(beg_id), max(end_id) 
  from (
          select /*+ index_rsd (a sys.WRM\\$_SNAPSHOT_PK) */ 
               snap_id end_id, snap_id beg_id
          from  sys.wrm\\$_snapshot a, v , v2
                where 
                   a.dbid = v2.dbid and  instance_number = inst 
                order by snap_id desc
        )
where rownum <=$ROWNUM ;
EOF`
 echo "$ret" | sed '/^$/d' | tr -d '\n'
# the output of 2 rows is the return of this function
}
# ---------------------------------------------------------------------------
function get_snap_beg_end
{
    ret=`sqlplus -s "$CONNECT_STRING"  <<EOF
set head off verify off feed off pause off
col beg_id new_value beg_id
col end_id new_value end_id

with v as ( select instance_number inst from   v\\$instance ) 
select  beg_id,end_id from (
  select beg_id,end_id,rank() over (order by rownum ) rn from (
select  rownum, snap_id beg_id, lag(snap_id,1) over (order by begin_interval_time desc ) end_id
        from
            sys.wrm\\$_snapshot a, v
         where instance_number=inst $AND_DBID
        order by begin_interval_time desc)) where rn=2;
EOF`
 echo "$ret" | sed '/^$/d' | tr -d '\n'
# the output of 2 rows is the return of this function
}
# ---------------------------------------------------------------------------
#    Main
# ---------------------------------------------------------------------------
if [ "$1" = "-h" -o -z "$1" ];then
   help
fi
AWR=FALSE
TYPE=1
ROWNUM=30
while [ -n "$1" ]
do
  case "$1" in
     -dbid ) DBID=$2; shift ;;
    -inst) INST_NUM=$2 ; SHOW_INST=TRUE; shift ;;
        -l ) CHOICE=CURR_MET ;; 
       -l2 ) CHOICE=CURR_MET ; TYPE=2 ;; 
        -s ) CHOICE=SUMMARY ;; 
       -s2 ) CHOICE=SUMMARY ; TYPE=2 ;; 
    -b|-b1 ) AWR=TRUE ; SNAP1=$2 ; shift ;;
    -e|-e1 ) AWR=TRUE ; SNAP2=$2 ; shift ;;
        -i ) METRIC_ID=$2 ; shift  ;;
        -f ) CHOICE=OVERVIEW ;;
       -f2 ) CHOICE=OVERVIEW_13 ;;
       -r2 ) CHOICE=LAST_20 ;;
       -rn ) ROWNUM=$2 ; shift ;;
        -v ) VERBOSE=TRUE; set -xv;;
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


if [ -n "$DBID" ];then
    AND_DBID=" and dbid= '$DBID'"
elif [ -z "$DBID" ];then
    SHOW_INST=${SHOW_INST:-FALSE}
    ret=`sqlplus -s "$CONNECT_STRING"<<EOF
    set head off verify off pause off
         select dbid , i.instance_number from sys.v_\\$database d, sys.v_\\$instance i;
EOF`
    ret=`echo $ret| tr -d '\n'|tr -d '\r'`
    DBID=`echo "$ret" |awk '{print $1}'`
    AND_DBID=" and dbid= '$DBID'"
    if [ -z "$INST_NUM" ];then
       INST_NUM=`echo "$ret" |awk '{print $2}'`
    fi
fi

if [ -n "INST_NUM" ];then
     AND_INST_NUM=" and instance_number = $INST_NUM"
fi

if [ "$CHOICE" = "OVERVIEW_13"  ];then
SQL="
set lines 190 pages 66
col class for a20 head 'Wait Class'
col BEGIN_TIME head 'Begin'
col END_TIME head 'End'
select
      to_char(BEGIN_TIME,'hh24:Mi:SS') begin_time,
      to_char(END_TIME,'hh24:Mi:SS') end_time,
      m.wait_class# id, n.wait_class class,
      AVERAGE_WAITER_COUNT ,
      DBTIME_IN_WAIT, m.TIME_WAITED, WAIT_COUNT, m.TIME_WAITED_FG, WAIT_COUNT_FG
    from v\$waitclassmetric  m, v\$system_wait_class n
 where m.wait_class_id=n.wait_class_id
             and n.wait_class != 'Idle'
/
"
# ....................................................................................................
#  Something to improve. 
#  found on http://www.oraclerealworld.com/oracle-cpu-time/ from Kyle HAiley
# ....................................................................................................
elif [ "$CHOICE" = "OVERVIEW"  ];then

SQL="
set lines 190 pages 66
col metric_name for a25
col metric_unit for a25

with AASSTAT as (
           select
                 decode(n.wait_class,'User I/O','User I/O',
                                     'Commit','Commit',
                                     'Wait')                               CLASS,
                 sum(round(m.time_waited/m.INTSIZE_CSEC,3))                AAS,
                 BEGIN_TIME ,
                 END_TIME
           from  v\$waitclassmetric  m,
                 v\$system_wait_class n
           where m.wait_class_id=n.wait_class_id
             and n.wait_class != 'Idle'
           group by  decode(n.wait_class,'User I/O','User I/O', 'Commit','Commit', 'Wait'), BEGIN_TIME, END_TIME
          union
             select 'CPU_ORA_CONSUMED'                                     CLASS,
                    round(value/100,3)                                     AAS,
                 BEGIN_TIME ,
                 END_TIME
             from v\$sysmetric
             where metric_name='CPU Usage Per Sec'
               and group_id=2
          union
            select 'CPU_OS'                                                CLASS ,
                    round((prcnt.busy*parameter.cpu_count)/100,3)          AAS,
                 BEGIN_TIME ,
                 END_TIME
            from
              ( select value busy, BEGIN_TIME,END_TIME from v\$sysmetric where metric_name='Host CPU Utilization (%)' and group_id=2 ) prcnt,
              ( select value cpu_count from v\$parameter where name='cpu_count' )  parameter
          union
             select
               'CPU_ORA_DEMAND'                                            CLASS,
               nvl(round( sum(decode(session_state,'ON CPU',1,0))/60,2),0) AAS,
               cast(min(SAMPLE_TIME) as date) BEGIN_TIME ,
               cast(max(SAMPLE_TIME) as date) END_TIME
             from v\$active_session_history ash
              where SAMPLE_TIME >= (select BEGIN_TIME from v\$sysmetric where metric_name='CPU Usage Per Sec' and group_id=2 )
               and SAMPLE_TIME < (select END_TIME from v\$sysmetric where metric_name='CPU Usage Per Sec' and group_id=2 )
)
select
       to_char(BEGIN_TIME,'HH:MI:SS') BEGIN_TIME,
       to_char(END_TIME,'HH:MI:SS') END_TIME,
       ( decode(sign(CPU_OS-CPU_ORA_CONSUMED), -1, 0, (CPU_OS - CPU_ORA_CONSUMED )) +
       CPU_ORA_CONSUMED +
        decode(sign(CPU_ORA_DEMAND-CPU_ORA_CONSUMED), -1, 0, (CPU_ORA_DEMAND - CPU_ORA_CONSUMED ))) CPU_TOTAL,
       decode(sign(CPU_OS-CPU_ORA_CONSUMED), -1, 0, (CPU_OS - CPU_ORA_CONSUMED )) CPU_OS,
       CPU_ORA_CONSUMED CPU_ORA,
       decode(sign(CPU_ORA_DEMAND-CPU_ORA_CONSUMED), -1, 0, (CPU_ORA_DEMAND - CPU_ORA_CONSUMED )) CPU_ORA_WAIT,
       COMMIT,
       READIO,
       WAIT
from (
select
       min(BEGIN_TIME) BEGIN_TIME,
       max(END_TIME) END_TIME,
       sum(decode(CLASS,'CPU_ORA_CONSUMED',AAS,0)) CPU_ORA_CONSUMED,
       sum(decode(CLASS,'CPU_ORA_DEMAND'  ,AAS,0)) CPU_ORA_DEMAND,
       sum(decode(CLASS,'CPU_OS'          ,AAS,0)) CPU_OS,
       sum(decode(CLASS,'Commit'          ,AAS,0)) COMMIT,
       sum(decode(CLASS,'User I/O'        ,AAS,0)) READIO,
       sum(decode(CLASS,'Wait'            ,AAS,0)) WAIT
from AASSTAT)
/
"
# ....................................................................................................
elif [ "$CHOICE" = "LAST_20" ];then
TITTLE='List last $ROWNUM for some metrics'
 if [ -z "$SNAP1" ];then
     VAR=`get_range_snap`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f1 -d' '`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
 elif [ -z "$SNAP2" ];then
      SNAP2=`expr $SNAP1 + 1`
 fi
 AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2"
SQL="
col pysr head 'Reads|Per Sec' justify c
col pysw head 'Writes|Per Sec' justify c
col fcom head 'Commits|Per Sec' justify c
col fcpu head 'DB time|Per Sec' justify c
col rlbk head 'Rollback|Per Sec' justify c

with b0 as ( select dbid fdbid from v\$database )
,b as ( select instance_number  as inst from v\$instance )
 ,v as ( select snap_id ,
               to_char( BEGIN_INTERVAL_TIME,'MM-DD HH24:MI:SS') beg,
               to_char( END_INTERVAL_TIME,'HH24:MI:SS') end
        from sys.wrm\$_snapshot a, b , b0
        where a.instance_number = b.inst $AND_SNAP )
,v1 as ( -- read per second
    select snap_id, round(avg(value)) value
     from DBA_HIST_SYSMETRIC_HISTORY a , b , b0
        where instance_number = b.inst and a.dbid = fdbid and
              group_id = 2 and METRIC_ID=2004   $AND_SNAP
     group by snap_id
)
,v2 as ( -- write per second
    select snap_id, round(avg(value)) value 
     from DBA_HIST_SYSMETRIC_HISTORY a , b, b0
        where instance_number = b.inst and a.dbid = fdbid and
              group_id = 2 and METRIC_ID=2006   $AND_SNAP
     group by snap_id
)
,v3 as ( -- Commits
    select /*+ no_merge */ snap_id, round(avg(value)) value 
     from DBA_HIST_SYSMETRIC_HISTORY a , b, b0
        where instance_number = b.inst and a.dbid = fdbid and
              group_id = 2 and METRIC_ID=2022   $AND_SNAP
     group by snap_id
)
,v3b as ( -- rollback
    select /*+ no_merge */ snap_id, round(avg(value)) value 
     from DBA_HIST_SYSMETRIC_HISTORY a , b, b0
        where instance_number = b.inst and a.dbid = fdbid and
              group_id = 2 and METRIC_ID=2024   $AND_SNAP
     group by snap_id
)
 ,v4 as ( -- CPU
    select snap_id, round(avg(value)) value 
     from DBA_HIST_SYSMETRIC_HISTORY a , b, b0
        where instance_number = b.inst and a.dbid = fdbid and
              group_id = 2 and METRIC_ID=2123  $AND_SNAP
     group by snap_id
)
select 
     v.snap_id, v.beg, v.end , v1.value pysr, v2.value pysw
     , v3.value fcom , v4.value fcpu, v3b.value rlbk
 from v, v1, v2 , v3, v3b ,v4
where 
        v.snap_id = v1.snap_id(+)
    and v.snap_id = v2.snap_id(+)
    and v.snap_id = v3.snap_id(+)
    and v.snap_id = v3b.snap_id(+)
    and v.snap_id = v4.snap_id(+)
   order by snap_id desc 
/
" 

# ....................................................................................................
#  Show current metrics
# ....................................................................................................
#
#  GROUP_ID NAME                                                             INTERVAL_SIZE MAX_INTERVAL
#---------- ---------------------------------------------------------------- ------------- ------------
#         0 Event Metrics                                                             6000            1
#         1 Event Class Metrics                                                       6000           60
#        11 I/O Stats by Function Metrics                                             6000           60
#         2 System Metrics Long Duration                                              6000           60
#         3 System Metrics Short Duration                                             1500           12
#         4 Session Metrics Long Duration                                             6000           60
#         5 Session Metrics Short Duration                                            1500            1
#         6 Service Metrics                                                           6000           60
#         7 File Metrics Long Duration                                               60000            6
#         9 Tablespace Metrics Long Duration                                          6000            0
#        10 Service Metrics (Short)                                                    500           24
#        12 Resource Manager Stats                                                    6000           60
#        13 WCR metrics                                                               6000           60
#        14 WLM PC Metrics                                                             500           24
# ....................................................................................................
elif [ "$CHOICE" = "CURR_MET" -a "$AWR" != TRUE ];then
TITTLE='List current metrics'

    if [ $TYPE = 2 ];then
        GROUP_ID=" a.group_id =2 and a.metric_unit like '%Second' "
    else
        GROUP_ID=" a.group_id !=3 and a.group_id !=4 and a.group_id != 5"
    fi
SQL="
 col name for a45
 col group_name for a35
 col id head 'Stat|Id' justify c
 col METRIC_UNIT for a30 head 'Unit'
 col id for 9999 justify c
 col value for 999999990.9 head ' Value'  justify l
 col dur head 'Dura|Cents' format 99999

 select ID, begin, end, INTSIZE_CSEC dur, name, value, metric_unit
 from (
 select a.group_id,
        a.METRIC_ID id,
        to_char(a.begin_time,'HH24:MI:SS')begin,
        to_char(a.end_time,'HH24:MI:SS')end,
INTSIZE_CSEC,
        a.metric_name name,
        case
          when a.METRIC_UNIT = 'bytes' then round(a.value/1048576,1)
          when a.METRIC_UNIT = 'Bytes Per Second' then round(a.value/1048576,0)
          else round(a.value)
        end value,
        case
             when a.METRIC_UNIT = 'bytes' then 'Megabyte per second'
             when a.METRIC_UNIT = 'Bytes Per Second' then 'Megabyte per second'
             else a.METRIC_UNIT
        end METRIC_UNIT
from V\$SYSMETRIC a
   where  $GROUP_ID
       and a.value > 0  
)
order by group_id, ID
/
"
# ....................................................................................................
#  Metric summary for a given period
# ....................................................................................................
elif [ "$CHOICE" = "CURR_MET" -a "$AWR" = TRUE ];then
TITTLE='List metrics from a given period'
  # if SNAP1 is empty then we do not enter here as $AWR!=TRUE
  # si SNAP1 has a value
  if [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     echo "Using default -b <nn> + 1> --> $SNAP2"
     AND_SNAP=" and snap_id = $SNAP1 "
  else
     # the two snap boundaries where given so includs them both
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  fi
  if [ -n "$METRIC_ID" ];then 
     AND_METRIC_ID=" and metric_id = $METRIC_ID " 
  fi

SQL="
 col name for a50
 col id head 'Stat|Id' justify c
 col METRIC_UNIT for a30 head 'Unit'
 col id for 9999 justify c
 col max head 'Last|Hour|Max' for 99999990 justify c
 col min head 'Last|Hour|Min' for 999990 justify c
 col average head 'Last|hour|Avg' for 999990 justify c
 col std_dev head 'Last|hour|standard|deviation' for 999999990.99 justify c
col value for 9999999990.9 head 'Value'  justify c

 select snap_id,ID, begin, end, name, value, metric_unit
 from (
 select group_id, snap_id,
        METRIC_ID id,
        to_char(begin_time,'HH24:MI:SS')begin,
        to_char(end_time,'HH24:MI:SS')end,
        metric_name name,
        case
          when METRIC_UNIT = 'bytes' then round(value/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(value/1048576,0)
          else round(value)
        end value,
        case
             when METRIC_UNIT = 'bytes' then 'Megabyte per second'
             when METRIC_UNIT = 'Bytes Per Second' then 'Megabyte per second'
             else METRIC_UNIT
        end METRIC_UNIT
from  DBA_HIST_SYSMETRIC_HISTORY 
   where group_id != 4 and group_id !=3 and group_id !=5  $AND_SNAP $AND_DBID $AND_METRIC_ID
         and  value > 0 
)
order by snap_id,group_id, ID
/
"
# ....................................................................................................
#  Metric summary (current period)
# ....................................................................................................
elif [ "$CHOICE" = "SUMMARY"  -a "$AWR" != TRUE ];then
TITTLE='List metrics summary'


    if [ $TYPE = 2 ];then
        GROUP_ID=" a.group_id =2 and a.metric_unit like '%Second' "
    else
        GROUP_ID=" a.group_id !=3 and a.group_id !=4 and a.group_id != 5"
    fi

SQL="
 col name for a50 head 'Metric name'
 col METRIC_UNIT for a30 head 'Unit'
 col id for 9999 justify c head 'Metr|id'
 col gid for 999 head 'Grp|ID' justify c
 col max head 'Max' for 9999990.9 justify c
 col min head 'Min' for 9999990.9 justify c
 col average head 'Avg' for 99990.9 justify c
 col std_dev head 'standard|deviation' for 99990.99
 col begin_date head 'Begin|Time'
 col end_date head 'End|Time'
 select 
        -- group_id gid,
        METRIC_ID id, 
        to_char(begin_time,'HH24:MI:SS')begin_date,
        to_char(end_time,'HH24:MI:SS')end_date,
        metric_name name,
        case
          when METRIC_UNIT = 'bytes' then round(MAXVAL/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(MAXVAL/1048576,1)
          else round(MAXVAL) 
        end max,
        case
          when METRIC_UNIT = 'bytes' then round(MINVAL/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(MINVAL/1048576,1)
          else round(MINVAL) 
        end min,
        case
          when METRIC_UNIT = 'bytes' then round(average/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(average/1048576,1)
          else round(average) 
        end average,
        case
          when METRIC_UNIT = 'bytes' then round(STANDARD_DEVIATION/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(STANDARD_DEVIATION/1048576,1)
          else round(STANDARD_DEVIATION) 
        end std_dev, 
         case 
             when METRIC_UNIT = 'bytes' then 'Megabyte per second'
             when METRIC_UNIT = 'Bytes Per Second' then 'Megabyte per second'
             else METRIC_UNIT
         end METRIC_UNIT
from   v\$SYSMETRIC_summary a
     where  $GROUP_ID
      and  MAXVAL > 0 
order by GROUP_ID, METRIC_ID
/
"
# ....................................................................................................
#  Metric summary
# ....................................................................................................
elif [ "$CHOICE" = "SUMMARY"  -a "$AWR" = "TRUE" ];then

  if [ -z "$SNAP1" ];then
     VAR=`get_snap_beg_end`
     VVAR=`echo $VAR | sed '/^$/d' |  cut -f1 -d':'`
     SNAP1=`echo $VVAR | cut -f2 -d' '`
     SNAP1=`echo $SNAP1 - 24`
     SNAP2=`echo $VVAR | cut -f2 -d' '`
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id < $SNAP2 "
  elif [ -z "$SNAP2" ];then
     echo "Value of SNAP1=$SNAP1, but no value given for end snap. "
     SNAP2=`expr $SNAP1 + 1`
     echo "Using default -b <nn> + 1> --> $SNAP2"
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id < $SNAP2 "
  else
     # the two snap boundaries where given so includs them both
     AND_SNAP=" and snap_id >= $SNAP1 and snap_id <= $SNAP2 "
  fi
  if [ -n "$METRIC_ID" ];then
     AND_METRIC_ID=" and metric_id = $METRIC_ID "
  fi


TITTLE="List metrics summary during each snap. Period from snap : $SNAP1 to $SNAP2"

SQL="
 col name for a50 head 'Metric name'
 col METRIC_UNIT for a30 head 'Unit'
 col id for 9999 justify c head 'Metr|id'
 col gid for 999 head 'Grp|ID' justify c
 col max head 'Max' for 9999990.9 justify c
 col min head 'Min' for 9999990.9 justify c
 col average head 'Avg' for 99990.9 justify c
 col std_dev head 'standard|deviation' for 99990.99
 col begin_date head 'Begin|Time'
 col end_date head 'End|Time'

 select 
        snap_id,
        METRIC_ID id, 
        to_char(begin_time,'HH24:MI:SS')begin_date,
        to_char(end_time,'HH24:MI:SS')end_date,
        metric_name name,
        case
          when METRIC_UNIT = 'bytes' then round(MAXVAL/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(MAXVAL/1048576,1)
          else round(MAXVAL) 
        end max,
        case
          when METRIC_UNIT = 'bytes' then round(MINVAL/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(MINVAL/1048576,1)
          else round(MINVAL) 
        end min,
        case
          when METRIC_UNIT = 'bytes' then round(average/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(average/1048576,1)
          else round(average) 
        end average,
        case
          when METRIC_UNIT = 'bytes' then round(STANDARD_DEVIATION/1048576,1)
          when METRIC_UNIT = 'Bytes Per Second' then round(STANDARD_DEVIATION/1048576,1)
          else round(STANDARD_DEVIATION) 
        end std_dev, 
         case 
             when METRIC_UNIT = 'bytes' then 'Megabyte per second'
             when METRIC_UNIT = 'Bytes Per Second' then 'Megabyte per second'
             else METRIC_UNIT
         end METRIC_UNIT
from  DBA_HIST_SYSMETRIC_SUMMARY 
      where  group_id !=3 and group_id !=5 $AND_SNAP $AND_DBID $AND_METRIC_ID
order by snap_id, group_id, metric_id
/
"
fi


# we do the work here

if [ -n "$VERBOSE" ];then
  echo "$SQL"
  set -x
fi

sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 120
column nline newline
prompt MACHINE $HOST - ORACLE_SID : $ORACLE_SID 
set pagesize 66 termout on embedded off verify off heading off pause off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '     - $TITTLE' from sys.dual
/

set head on pause off feed on  linesize 190
$SQL
prompt
EOF

