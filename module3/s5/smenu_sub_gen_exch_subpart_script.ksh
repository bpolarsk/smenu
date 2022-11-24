#!/bin/sh
# set -xv
# author :  B. Polarski
# 8 Juillet 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
typeset -u WRK_TBL
typeset -u GOOD_TBS
typeset -u OWNER
GOOD_TBS=$1
OWNER=$2
WRK_TBL=$3
if [ -z "$WRK_TBL" ];then
   echo "I do not have the working table"
   exit
fi
if [ -z "$OWNER" ];then
   echo "I do not have the owner table"
   exit
fi
if [ -z "$GOOD_TBS" ];then
   echo "I do not have the working tablespace"
   exit
fi
if [ -z "$4" ];then
   FOUT=$SBIN/tmp/scr_drop_sub_part_${WRK_TBL}_$$.txt
else
   FOUT=$4
fi
# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------


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
       'Generated missing partitions and subpartitions' nline
from sys.dual
/

set head off

set linesize 120
set pagesize 0 feed off
spool $FOUT
select  
        'create table $OWNER' || '.'||table_name|| '_x tablespace $GOOD_TBS as select * from $OWNER.'||  table_name || ' where 1=2;' 
       ,'alter table $OWNER.'|| table_name|| ' exchange subpartition '|| subpartition_name || ' with table $OWNER.'||table_name||'_x ;'
       , 'drop table '|| table_OWNER || '.' || table_name || '_x ;'
  from dba_tab_subpartitions 
       where table_OWNER  = '$OWNER'
             and table_name = '$WRK_TBL' 
             and tablespace_name  in (
                 select distinct tablespace_name from dba_data_files
                        where tablespace_name not like 'SYS%'
                              and exists ( select file#  from v\$datafile 
                                                  where file# = file_id and name like '%MISSING%'
 ))
union all
 select distinct 'alter table '|| table_owner || '.' || table_name || ' drop partition ' || partition_name || ';' 
      , null ,null
      from dba_tab_subpartitions
         where table_OWNER  = '$OWNER'
               and table_name = '$WRK_TBL'
               and tablespace_name  in (
                 select distinct tablespace_name from dba_data_files
                        where tablespace_name not like 'SYS%'
                              and exists ( select file#  from v\$datafile 
                                   where file# = file_id and name like '%MISSING%'
 )) 
/

spool off
EOF
