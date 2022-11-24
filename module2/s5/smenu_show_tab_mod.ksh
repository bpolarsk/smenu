#!/bin/ksh
#set -xv
# author :  B. Polarski
# 29 October 2007
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
function help
{
cat <<EOF

            mod -l  [-u <OWNER>][-t <TBL>]     : list
            mod -lu [<OBJECT_NAME>] -u <OWNER> : list monitored objects. If no objects name given, list all monitored
            mod -h                             : this help
            mod -x                             : refresh dba_tab_modifications
            mod -s <OBJECT_NAME> -u <OWNER>    : set monitoring on <OBJECT_NAME>
            mod -n <OBJECT_NAME> -u <OWNER>    : disable monitoring on <OBJECT_NAME>


            -u         : Schema name
            -r <nn>    : limit list to <n> rows

EOF
exit
}
if [ -z "$1" ];then
   help
fi
ROWNUM=31

while [ -n "$1" ]
do
  case "$1" in
      -l ) CHOICE=DEFAULT;;
      -lu ) CHOICE=LIST_MONITORED
            if [ "$2" != "-u" ];then
                 AND_TABLE_NAME=" and table_name = '$2'" ; shift
             fi ;;
      -h ) help ;;
      -s ) CHOICE=SET_MONITOR; OBJECT=$2 ; shift; MONITOR=MONITORING;;
      -n ) CHOICE=SET_MONITOR; OBJECT=$2 ; shift; MONITOR=NOMONITORING;;
      -x ) CHOICE=REFRESH_INFO;;
      -r ) ROWNUM=$2;shift ;;
      -t ) TBL=$2;shift  ;;
      -v ) set -x ;;
      -u ) OWNER=$2; shift
           AND_OWNER=" And table_owner = upper('$OWNER') " ;;
       * ) help
  esac
  shift
done

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# --------------------------------------------------------------------------
if [ "$CHOICE" = "LIST_MONITORED" ];then
   if [ -z "$OWNER" ];then
      echo "In order to user V\$OBJECT_USAGE, it is mandatory to provide the obejct name owner"
      exit
   fi

export S_USER=$OWNER
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $OWNER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
  SQL="set lines 159 pages 66
  col used for A4
  select table_name, index_name,MONITORING, used,
         START_MONITORING, nvl(END_MONITORING,
        'Monitor active') END_MONITORING
  from v\$object_usage order by 1 ;"
# --------------------------------------------------------------------------
elif [ "$CHOICE" = "SET_MONITOR" ];then
   if [ -z "$OWNER" ];then
         echo "I need a schema for this operation"
         exit
   fi
SQL="col usage new_value usage noprint
select decode(object_type,'INDEX'
                          ,'alter index  ${OWNER}.${OBJECT} $MONITOR usage'
                          ,'alter table  ${OWNER}.${OBJECT} $MONITOR') usage from dba_objects where OWNER=upper('$OWNER')
       and object_name = upper('$OBJECT');
prompt usage=&usage
declare
begin
   execute  immediate ('&usage');
end;
/
"
# --------------------------------------------------------------------------
elif [ "$CHOICE" = "REFRESH_INFO" ];then

echo "--> exec DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO; "
SQL="exec DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO; "

# --------------------------------------------------------------------------
elif [ "$CHOICE" = "DEFAULT" ];then

   if [ -n "$TBL" ];then
      AND_TBL=" and TABLE_NAME = upper('$TBL') "
   fi

SQL="select table_owner, table_name , PARTITION_NAME, mutations, inserts, deletes, updates,to_char(timestamp,'YYYY-MM-DD HH24:MI:SS') tt
from (
select table_owner, table_name, PARTITION_NAME, inserts + deletes + updates mutations,
inserts, deletes, updates, timestamp
from all_tab_modifications 
 where table_owner != 'SYS' and table_owner != 'SYSTEM' and table_owner != 'SYSMAN' $AND_OWNER $AND_TBL
order by mutations desc
) where rownum < $ROWNUM ;"

fi


sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 190 termout on pause off embedded on verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Show top 30 tables modified, excluding sys, system and sysman user' nline
from sys.dual
/

set head on
break on owner
COL table_owner          FORMAT  A25 heading 'Owner'
COL table_name           FORMAT  A25 heading 'Table'
COL PARTITION_NAME           FORMAT  A25 heading 'Table partition'
COL mutations            FORMAT  999,999,999,999,999   justify c HEADING ' Total|Mutations'
COL tt                   FORMAT  A19   justify c HEADING ' Last time|modification'

$SQL

EOF

