#!/bin/sh
# set -xv
# B. Polarski
# 5 Sep 2005
WK_SBIN=$SBIN/module2/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
S_USER=SYS
INTERVAL=${1:-60}
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
set -x
GOOD_TBS=`sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 190 pagesize 0 feed off  head off pause off verify off termout on
select tablespace_name from (
                 select distinct tablespace_name from dba_data_files where tablespace_name not like 'SYS%'
                       and not exists ( select file#  from v\\$datafile where file# = file_id and name like '%MISSING%')
     )
   where rownum = 1
/
EOF`
$SBINS/smenu_check_exists.sh SYS.HOSTS_STATS
if [ ! $? -eq 0 ];then
   # there some file in autoextent

sqlplus -s "$CONNECT_STRING" <<EOF

prompt creating the stats_system table
EXEC DBMS_STATS.create_stat_table(ownname => 'SYS', STATTAB => 'HOST_STATS', tblspace => '$GOOD_TBS' )
/
EOF

else  # table host_stats already exists
 :
fi

sqlplus -s "$CONNECT_STRING" <<EOF
EXECUTE DBMS_STATS.GATHER_SYSTEM_STATS(GATHERING_MODE => 'INTERVAL',INTERVAL=> 2,STATTAB =>'HOST_STATS',STATID =>'HOST_STATS')
/
EOF
sleep 122
sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 124;
select STATID, C1, C2, C3 from SYS.HOST_STATS
/
execute DBMS_STATS.IMPORT_SYSTEM_STATS(stattab => 'HOST_STATS', statid => 'HOST_STATS', statown =>'SYS')
/
select * from sys.aux_stats\$
/
exit
EOF
