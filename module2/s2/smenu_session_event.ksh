#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
if [ -n "$1" ];then
   SID=" and s.sid = $1"
fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Session Hit' nline
from sys.dual
/
prompt
prompt  Type slh <sid> to limit to one session
set heading on
set linesize 110
col BCHNG head "Block |Changes" justify c
col CCHNG head "Consistent|Changes" justify c
col Cgets head "Consistent|Gets" justify c
col Pread head "Physical|Reads" justify c
set lines 150;
select substr(s.sid,1,3) sid,substr(s.username,1,10) Username,
       substr(osuser,1,8) osuser,spid ospid,
       substr(status,1,3) stat,substr(command,1,3) com,
       substr(schemaname,1,10) schema,
       substr(type,1,5) typ,
       value CPU,
       substr(block_changes,1,8) bchng,
       substr(consistent_changes,1,8) cchng,
       substr(consistent_gets,1,8) cgets,
       substr(physical_reads,1,8) pread,
       substr(decode((consistent_gets+block_gets),0,'None',
             (100*(consistent_gets+block_gets-physical_reads)/
             (consistent_gets+block_gets))),1,4) "%HIT"
from v\$process p, v\$SESSTAT t,v\$sess_io i ,v\$session s
where i.sid=s.sid and p.addr=paddr(+) and s.sid=t.sid and
t.statistic#=12 $SID
/ 
exit

EOF
