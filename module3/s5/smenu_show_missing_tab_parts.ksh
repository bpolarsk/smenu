#!/bin/sh
# set -xv
# author :  B. Polarski
# 8 Juillet 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
typeset -u ftable
if [ -n "$1" ] ;then
    ftable=$1
    ALL='and table_name = $ftable'
else
    echo " Table name (press <ENTER> to list all)====== > \c"
    read ftable
fi
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------

if [ -z "$ftable" ];then
   unset ALL
else
  ALL="and table_name = '$ftable'"
fi

sqlplus -s "$CONNECT_STRING"  <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 190
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show missing partitions and subpartitions' nline
from sys.dual
/

set head on
break on partition_name
COL table_name               FORMAT  A22 heading 'Table name'
COL partition_name           FORMAT  A22 heading 'Partition name'
COL subpartition_name        FORMAT  A22 heading 'System generated|Subpartition name'
COL tablespace_name          FORMAT  A24   justify c HEADING ' Tablespace name'
COL file_id                  FORMAT  9999   justify c HEADING ' File| Id'
COL table_owner              FORMAT  A18   justify l HEADING 'Owner'


set linesize 190
set pagesize 0 feed off
set head on
break on tablespace_name on table_name on partition_name


set linesize 190
set pagesize 0 feed off
set head on
break on tablespace_name on table_name on partition_name

select a.tablespace_name, table_name,  partition_name, subpartition_name , file_id , a.table_owner
         from dba_tab_subpartitions a, (
                 select distinct tablespace_name,file_id from dba_data_files
                        where tablespace_name not like 'SYS%' 
                       and exists ( select file#  from v\$datafile where file# = file_id and name like '%MISSING%')
         ) b
         where table_OWNER not like '%SYS%'
              and a.tablespace_name  in (
                 select distinct tablespace_name from dba_data_files
                        where tablespace_name not like 'SYS%' 
                       and exists ( select file#  from v\$datafile where file# = file_id and name like '%MISSING%')) $ALL
   order by a.tablespace_name, a.table_name, a.partition_name, a.subpartition_name 

/
EOF
