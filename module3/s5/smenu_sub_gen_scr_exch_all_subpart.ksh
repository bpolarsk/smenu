#!/bin/sh
# set -xv
# author :  B. Polarski
# 8 Juillet 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
typeset -u WRK_TBL
typeset -u GOOD_TBS
typeset -u OWNER

help()
{
  cat <<EOF

   This script will exchange all subpartitions of all users in all tablespaces 
   if the subpartition is non existing. This will happen if you use an 
   'RMAN skip tablspace' and your tablespaces contains partitioned tables


      smenu_sub_gen_scr_exch_all_subpart.ksh -f <OWNER> -b <TABLESPACE> -f <FILEOUT>

  using short_cuts : smtga
  
   You can restrict the effect using the following options

   -o <OWNER>      : only process sub partitions of <OWNER>
   -b <TABLESPACE> : only process sub partitions in <TABLESPACE>
   -f <FILE OUT>   : Create the scripts in <FILE OUT>

EOF
}
FOUT=$SBIN/tmp/scr_drop_all_sub_part_${WRK_TBL}_$$.txt
#
while getopts o:b:f:h ARG
  do
  case $ARG in
    f) FOUT=$OPTARG ;;
    b) GOOD_TBS=$OPTARG ;;
    o) OWNER=$OPTARG 
       AND_OWNER="table_owner = '$OWNER' and ";;
    h ) help
       exit ;;
  esac
done

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------

if [ -z "$GOOD_TBS" ];then
   GOOD_TBS=`sqlplus -s "$CONNECT_STRING" <<EOF
set linesize 190 pagesize 0 feed off  head off pause off verify off termout on
select tablespace_name from (
                 select distinct tablespace_name from dba_data_files where tablespace_name not like 'SYS%' 
                       and not exists ( select file#  from v\\$datafile where file# = file_id and name like '%MISSING%')
     )
   where rownum = 1
/
EOF`
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
       'Generated missing partitions and subpartitions' nline
from sys.dual
/

set head off

set linesize 120
set pagesize 0 feed off
spool $FOUT
select  
        'create table '|| table_owner || '.'||table_name|| '_x tablespace $GOOD_TBS as select * from '||table_owner||'.'||  table_name || ' where 1=2;' 
       ,'alter table '|| table_owner||'.'|| table_name|| ' exchange subpartition '|| subpartition_name || ' with table ' ||table_owner||'.'||table_name||'_x ;'
       , 'drop table '|| table_OWNER || '.' || table_name || '_x ;'
  from dba_tab_subpartitions 
       where $AND_OWNER
             tablespace_name  in (
                 select distinct tablespace_name from dba_data_files
                        where tablespace_name not like 'SYS%'
                              and exists ( select file#  from v\$datafile 
                                                  where file# = file_id and name like '%MISSING%'
 ))
union all
 select distinct 'alter table '|| table_owner || '.' || table_name || ' drop partition ' || partition_name || ';' 
      , null ,null
      from dba_tab_subpartitions
         where $AND_OWNER
               tablespace_name  in (
                 select distinct tablespace_name from dba_data_files
                        where tablespace_name not like 'SYS%'
                              and exists ( select file#  from v\$datafile 
                                   where file# = file_id and name like '%MISSING%'
 )) 
/

spool off
EOF

echo "Results in $FOUT"
