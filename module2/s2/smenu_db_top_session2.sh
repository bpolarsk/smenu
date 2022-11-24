#!/usr/bin/ksh
#set -xv
#
# Find Highest CPU used Oracle processes and get the Username 
# and SID from oracle
# Only 3 character SIDNAME is displayed - Adjust the script according to your need.
#
#
#####################################
#
#  Setup of variables
#
#####################################

tmstmp=`date "+%y%m%d.%H%M%S"`

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

#####################################
#
#  Function Section
#
#####################################
ORA_SID=`echo $ORACLE_SID | awk '{printf("%-8.8s", $1)}'`

echo "                     Top 20 CPU Utilized Session from `hostname`"
echo "                     ============================================"
echo "O/S      Oracle           Session  Session    UNIX Login      Oracle   CPU Time"
echo "ID       User ID          Status        ID      ID Time SID     Used"
echo "-------- ---------------- -------- ------- ------- ---------- -------- --------"
ps -ef | grep LOCAL | awk '{ print $1" "$2" "$7" "$8" "$9}'| sort -r -k 3 | head -20 | while read LINE
do
        export CPUTIME=`echo $LINE | awk '{ print $3 }'`
        export UNIXPID=`echo $LINE | awk '{ print $2 }'`
        if [ $ORACLE_HOME != "NOSIDNAME" ];then
                export SHLIB_PATH=$ORACLE_HOME/lib:/usr/lib
                export TMPDIR=/tmp
                export LD_LIBRARY_PATH=$ORACLE_HOME/lib

$ORACLE_HOME/bin/sqlplus -s "$CONNECT_STRING" <<EOF
     set pages 0 lines 150 trims on echo off verify off pause off
    column pu format a8 heading 'O/S|ID' justify left
    column su format a16 heading 'Oracle|User ID' justify left
    column stat format a8 heading 'Session|Status' justify left
    column ssid format 999999 heading 'Session|ID' justify right
    column sser format 999999 heading 'Serial|No' justify right
    column spid format a7 heading 'UNIX|ID' justify right
    column ltime format a11 heading 'Login|Time'
    select p.username pu,
       s.username su,
       s.status stat,
       s.sid ssid,
       lpad(to_char(p.spid),7) spid,
       ltrim(to_char(s.logon_time, 'MMDD:HH24MISS')) ltime, ltrim('$ORA_SID'),'$CPUTIME'
    from v\$process p,
       v\$session s
    where    p.addr=s.paddr
    and      p.spid=$UNIXPID
     union all
     select a.username, 'Kill Me', 'NoOracle', a.pid,
     lpad(a.spid,7) spid, '', '$ORA_SID','$CPUTIME'
     from v\$process a
     where a.spid = $UNIXPID
     and not exists (select 1 from  v\$session s
                                where a.addr=s.paddr)
    ;
EOF
       fi

done
echo "-------- ----------- -------- ------- ------- ------- ----------- ------ --------"
date
#
# End of Script
