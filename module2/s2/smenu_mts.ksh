#!/bin/ksh
# Program : smenu_mts.ksh
# Author  : B. Polarski
# Date    : 21 Jun 2006
#
# -------------------------------------------------------------------------------------
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -------------------------------------------------------------------------------------
function do_execute
{
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 1 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  'Page:' format 999 sql.pno skip 2
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER, '$TITTLE ' from sys.dual
/
set head on linesize 124 pagesize 66
col PRESENTATION format a30
col network format a30
col messages format 99999999
col cpt head "Number of|Shared server"
col avg_wait format 9990.99 head "Average wait|in Hundredths| of seconds"
col conf_indx head "Idx|Num" format 999
col status format a6
col breaks format 99999
col service format a10
col OUTBD_TIMOUT head "Timeout|outbd"
col INBD_TIMOUT head "Timeout|inbd"
col time_busy head "%Time|Buzy" format 990.99
$SQL
EOF
}
# -------------------------------------------------------------------------------------
show_help()
{
   cat <<EOF


         Usage : mts -c -d -o


           Notes

             -o : overview
             -c : display circuits
             -d : display dispatchers config
            -df : display dispatchers figures
             -s : display shared_server_monitor figures
             -i : info on shared_server activity
           -ttl : dislay time to live stats

  TTL_LOOPS   Time-to-live for "loops" samples, reported in hundredths of a second. Default is 10 minutes.
  TTL_MSG     Time-to-live for "messages" samples, reported in hundredths of a second. Default is 10 seconds.
  TTL_SVR_BUF Time-to-live for "buffers to servers" samples, reported in hundredths of a second. Default is 1 second.
  TTL_CLT_BUF Time-to-live for "buffers to clients" samples, reported in hundredths of a second. Default is 1 second.
  TTL_BUF     Time-to-live for "buffers to clients/servers" samples, reported in hundredths of a second. Def is 1 second.
  TTL_RECONNECT   Time-to-live for "reconnections" samples, reported in hundredths of a second. Default is 10 minutes
  TTL_IN_CONNECT  Time-to-live for "inbound connections" samples, reported in hundredths of a second. Default is 10 minutes.
  TTL_OUT_CONNECT Time-to-live for "outbound connections" samples, reported in hundredths of a second. Default is 10 minutes.

EOF
}
# -------------------------------------------------------------------------------------
while [ -n "$1" ]
  do
    case $1 in
      -h ) show_help
           exit ;;
     -c ) ACTION=CIRCUIT ; TITTLE="Show circuits";;
     -d ) ACTION=DISP_CF ; TITTLE="Show dispatchers configuration";;
     -i ) ACTION=INFO ; TITTLE="info on shared_server activity";;
     -df ) ACTION=DISPATCHER ; TITTLE="Show dispatchers figures";;
     -o ) ACTION=OVERVIEW ; TITTLE="Overview" ;;
     -s )  ACTION=SERVER ; TITTLE="Display Shared_server_monitor" ;;
     -ttl ) ACTION=TTL ; TITTLE="Display time to live stats" ;;
     -v ) SETXV="set -xv" ;;
      * ) echo "Invalid option" ;;
  esac
  shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


# -------------------------------------------------------------------------------------
if [ "$ACTION" = "CIRCUIT" ];then
SQL="
set lines 159 pages 900
col name head 'Dispatcher' for a10
col status format a10
select 
       d.name, s.sid, s.status,  c.CIRCUIT,c.QUEUE,c.BYTES,c.BREAKS,c.PRESENTATION 
   from v\$circuit c, v\$session s, v\$dispatcher d
where
       c.saddr = s.saddr (+) and
       c.dispatcher = d.paddr (+)
order by d.name,s.status,s.sid
;
"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "INFO" ];then
SQL="select 
      name , paddr,requests, busy/(busy + idle)* 100 time_busy from v\$shared_server;
"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "SERVER" ];then
SQL="
  select 
  MAXIMUM_CONNECTIONS,MAXIMUM_SESSIONS,SERVERS_STARTED,SERVERS_TERMINATED,SERVERS_HIGHWATER
    from v\$shared_server_monitor
/
"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "TTL" ];then
SQL="select ttl_loops, ttl_msg, ttl_svr_buf,ttl_buf, ttl_in_connect, ttl_out_connect, ttl_reconnect
   from v\$dispatcher_rate ;"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "OVERVIEW" ];then
SQL="select avg_wait,cpt from (
        select decode(TOTALQ, 0, 0,WAIT/TOTALQ) avg_wait from v\$queue where type = 'COMMON'),
        (select count(*) cpt from v\$shared_server where status != 'QUIT' ) ;"
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "DISP_CF" ];then
SQL="select CONF_INDX,network,DISPATCHERS,CONNECTIONS,SESSIONS,POOL,MULTIPLEX,SERVICE,INBD_TIMOUT,OUTBD_TIMOUT
 from v\$dispatcher_config; "
# -------------------------------------------------------------------------------------
elif [ "$ACTION" = "DISPATCHER" ];then
SQL="
col busy head '%TIME BUSY' for 990.9
col bytes head 'Trafic(mb)' for 9999990.9
col service for a30
col network for a50
set lines 190
select name, status,
             (BUSY/(BUSY + IDLE)) * 100 BUSY, bytes/1048576 bytes,breaks,a.conf_indx,
             a.network, service, messages
            from v\$dispatcher a,v\$dispatcher_config b where a.conf_indx =  b.conf_indx ;"
fi
# -------------------------------------------------------------------------------------

do_execute

