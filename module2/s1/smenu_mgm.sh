#!/bin/ksh
# set -xv
# B. Polarski
# 25 Aout 2014
WK_SBIN=$SBIN/module2/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

cd $WK_SBIN
# --------------------------------------------------------------------------
function help
{
  cat <<EOF

  Show data from Management grid/dbconsole views.
  This is critical if you want to create trends reporting over customize measurements

     mgm -l                                                      : List objects (instance, listeners, etc...)
     mgm -l  -t <target_gui >                                    : List metrics for a given target

     mgm -l  -t <target_guid>  -m <metric_guid> -k <key value>   : List metrics for a given object
     mgm -lh <-t <target_guid>  -m <metric_guid> -k <key value>  : Same as -l but uses Hourly views
     mgm -ld <-t <target_guid>  -m <metric_guid> -k <key value>  : Same as -l but uses Daily  views
     mgm -av                                                     : List availability
 
     mgm -h                                                      : This help


Note :
       -t <target_guid>   : iotained using 'mgm -l'
       -k <key value >    : obtained using 'mgm -l -t <target_gui>'
       -m <metric guid>   : obtained using 'mgm -l -t <target_gui>'
       -d <nn>            : number of days to go back

Comments:
    a) If key value contains blanks enclosed it with doubles quotes : -k "on cpu"
    b) To find the proper -t and -m or -k, you must use mgm -l and not mgm -lh or -ld  
 
EOF
exit
}

# --------------------------------------------------------------------------
if [ -z "$1" ];then
    help
fi
ROWNUM=30
while [ -n "$1" ]
do
  case "$1" in
     -av ) CHOICE=AVAILABILITY ;;
      -d ) DAYS=$2 ; shift ;;
      -k ) KEY=$2 ; shift ;;
      -l ) CHOICE=LIST_TARGET;;
     -lh ) CHOICE=LIST_TARGET_HOURLY;;
     -ld ) CHOICE=LIST_TARGET_DAILY;;
      -m ) METRIC_GUID=$2; shift ;;
      -t ) TARGET_GUID=$2; shift ;;
     -rn ) ROWNUM=$2 ; shift ;;
      -v ) set -x ;;
      -h ) help ;;
       * ) help ;;
  esac
  shift
done
 if  [ "$CHOICE" = "LIST_TARGET" ];then
      if  [ ! -z "$TARGET_GUID" ];then
          if [ -z "$METRIC_GUID" ];then
             CHOICE=LIST_METRICS 
          else
             CHOICE=LIST_MET_VALUE
          fi
      fi
 fi
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
# a Nice query to list DB SLA
# found at http://ergemp.blogspot.com/2008/06/oracle-em-grid-control-custom-reports.html
# --------------------------------------------------------------------------
if [ "$CHOICE" = "AVAILABILITY" ];then

sqlplus -s "$CONNECT_STRING" <<EOF
set lines 190 pages 65
col TARGET_NAME for a45
select
 target_name,
 target_type,
 sum(up_time) up_time,
 sum(down_time) down_time,
 sum(blackout_time) blackout_time,
 trunc(sum(up_time)/(sum(nvl(up_time,1))+sum(nvl(down_time,1)))*100) availability_pct
from
(
select
 target_name,
 target_type,
 sum(trunc((nvl(end_timestamp,sysdate)-start_timestamp)*24)) total_hours,
 case availability_status
   when 'Target Down' then
     0
   when 'Target Up' then
     0
   when 'Blackout' then
     sum(trunc((nvl(end_timestamp,sysdate)-start_timestamp)*24))
 end blackout_time,
 case availability_status
   when 'Target Down' then
     0
   when 'Target Up' then
     sum(trunc((nvl(end_timestamp,sysdate)-start_timestamp)*24))
   when 'Blackout' then
     0
 end up_time,
 case availability_status
   when 'Target Down' then
     sum(trunc((nvl(end_timestamp,sysdate)-start_timestamp)*24))
   when 'Target Up' then
     0
   when 'Blackout' then
     0
 end down_time,
 availability_status
from
 sysman.MGMT\$AVAILABILITY_HISTORY
where
 target_type in ('oracle_database','rac_database') and
 availability_status in ('Target Down','Target Up','Blackout')
group by
 target_name, target_type, availability_status
order by target_name, availability_status
)
group by target_name, target_type
order by target_name
/

EOF
# --------------------------------------------------------------------------
elif [ "$CHOICE" = "LIST_TARGET_HOURLY" ];then
  if [ -z "$TARGET_GUID" ];then
      echo "You need a TARGET_GUID : use mgm "
      exit
   fi
   if [ -z "$METRIC_GUID" ];then
      echo "You need a TARGET_GUID : use mgm -m "
      exit
   fi
   if [ -n "$KEY" ];then
         AND_KEY=" and key_value ='$KEY'"
   fi
   if [ -n "$DAYS" ];then
       AND_DAYS=" and ROLLUP_TIMESTAMP >= trunc(sysdate ) - $DAYS "
   fi
sqlplus -s "$CONNECT_STRING" <<EOF
   set lines 190 pages 66
   col value for 99999999999999
   col name for a40

 select * from (
   select
      to_Char(ROLLUP_TIMESTAMP,'MM-DD HH24') as ldate
      ,VALUE_AVERAGE, VALUE_MAXIMUM ,VALUE_MINIMUM
   from
        MGMT_METRICS_1HOUR
   where
       TARGET_GUID='$TARGET_GUID' and METRIC_GUID='$METRIC_GUID' $AND_KEY $AND_DAYS
   order by 1 desc
  ) where rownum <= $ROWNUM
/
EOF

# --------------------------------------------------------------------------
elif [ "$CHOICE" = "LIST_TARGET_DAILY" ];then
  if [ -z "$TARGET_GUID" ];then
      echo "You need a TARGET_GUID : use mgm "
      exit
   fi
   if [ -z "$METRIC_GUID" ];then
      echo "You need a TARGET_GUID : use mgm -m "
      exit
   fi
   if [ -n "$KEY" ];then
         AND_KEY=" and key_value ='$KEY'"
   fi
   if [ -n "$DAYS" ];then
       AND_DAYS=" and ROLLUP_TIMESTAMP >= trunc(sysdate ) - $DAYS "
   fi

sqlplus -s "$CONNECT_STRING" <<EOF
   set lines 190 pages 66
   col value for 99999999999999
   col name for a40

 select * from (
   select
      to_Char(ROLLUP_TIMESTAMP,'YYYY-MM-DD') as ldate
      ,VALUE_AVERAGE,VALUE_MAXIMUM,VALUE_MINIMUM
   from
        MGMT_METRICS_1DAY
   where 
       TARGET_GUID='$TARGET_GUID' and METRIC_GUID='$METRIC_GUID' $AND_KEY $AND_DAYS
   order by 1 desc
  ) where rownum <= $ROWNUM
/
EOF

# --------------------------------------------------------------------------
elif [ "$CHOICE" = "LIST_MET_VALUE" ];then
   if [ -z "$TARGET_GUID" ];then
      echo "You need a TARGET_GUID : use mgm "
      exit
   fi
   if [ -z "$METRIC_GUID" ];then
      echo "You need a TARGET_GUID : use mgm -m "
      exit
   fi
   if [ -n "$KEY" ];then
         AND_KEY=" and key_value ='$KEY'"
   fi
   if [ -n "$DAYS" ];then
       AND_DAYS=" and COLLECTION_TIMESTAMP >= trunc(sysdate ) - $DAYS "
   fi

sqlplus -s "$CONNECT_STRING" <<EOF
   set lines 190 pages 66
   col value for 99999999999999
   col name for a40

 select * from (
   select 
      key_value name, value, to_char(COLLECTION_TIMESTAMP,'YYYY-MM-DD HH24:MI') ldate
   from 
       MGMT_METRICS_RAW
   where
       TARGET_GUID='$TARGET_GUID' and METRIC_GUID='$METRIC_GUID' $AND_KEY $AND_DAYS
  order by 3 desc
 ) where rownum <=  $ROWNUM
/
EOF

# --------------------------------------------------------------------------
elif [ $CHOICE = "LIST_METRICS" ];then

sqlplus -s "$CONNECT_STRING" <<EOF
   col KEY_VALUE for a30
   col METRIC_NAME for a45
   col TARGET_TYPE for a20
   col METRIC_COLUMN for a35
   col COLLECTION_NAME for a40
   set lines 190 pages 66

  select  metric_name, METRIC_COLUMN,  METRIC_GUID, COLLECTION_NAME , KEY_VALUE
  from
     MGMT\$TARGET_METRIC_SETTINGS
 where TARGET_GUID = '$TARGET_GUID'
 order by 2
/ 

EOF

# --------------------------------------------------------------------------
elif [ $CHOICE = "LIST_TARGET" ];then

sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 66 linesize 170 termout on pause off
col HOST_NAME for a30
col TARGET_NAME for a50
col TARGET_TYPE for a20

select HOST_NAME,TARGET_NAME,TARGET_TYPE,TARGET_GUID from SYSMAN.MGMT_TARGETS
order by 1,2
/

EOF

fi
