#!/bin/sh
# set -xv
# author :  B. Polarski
# 17 Agust 2005
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
COL table_name               FORMAT  A28 heading 'Partition name'
COL partition_name           FORMAT  A28 heading 'Partition name'
COL subpartition_name        FORMAT  A25 heading 'System generated|Subpartition name'
COL tablespace_name          FORMAT  A30   justify c HEADING ' Tablespace name'
COL file_id                  FORMAT  9999   justify c HEADING ' File| Id'


set linesize 190
set pagesize 0 feed off
set head off
break on tablespace_name on table_name on partition_name

col good_tbs new_value good_tbs noprint 

select tablespace_name good_tbs from (
             select distinct tablespace_name from dba_data_files 
                    where tablespace_name not like 'SYS%' 
                          and not exists ( 
                              select file# from v\$datafile 
                                           where file# = file_id and name like '%MISSING%')
     )
   where rownum = 1
/
Prompt I will use tablespace '&&good_tbs' to create my temporary tables
prompt
exit
EOF
