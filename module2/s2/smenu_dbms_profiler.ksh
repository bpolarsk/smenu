#!/bin/ksh
# Program : smenu_dbms_profiler.ksh
# Author  : B. Polarski
# Date    : 3 Septembre 2008
#
# set -x
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
set head on linesize 132 pagesize 66
col cver head "Code% coverage"
$DO_ALTER_SESS
$SQL
EOF
}
# -------------------------------------------------------------------------------------
show_help()
{
   cat <<EOF


         Usage :

              dpf  -u <PROFILER USER> -l               # list contents of dbms_profiler
              dpf  -u <PROFILER USER> -s -i <ID>       # Stats on top lines for run_id=ID
              dpf  -u <PROFILER USER> -p -i <ID>       # Show percent lines used

              dpf  -u <PROFILER USER> -t -i <ID> -o|-ms   -oo|-oms      # Summary for  run_id=ID

       create profiler user:

              dpf  -lcr <PROFILER USER>                # list statement to create profiler user. Default is 'PROFILER'

           Notes

             -rn <nn> : limit output to <nn> rows
             -o  <n>  : Limit output to lines with Occur >= n
             -ms <n>  : Limite output to lines with MS >= n
             -or_o    : Order put by occur desc
             -or_ms   : Order put by total_time desc

EOF
}
# -------------------------------------------------------------------------------------
ROWNUM=20
S_USER=SYS

if [ -z "$1" ];then
   show_help
   exit
fi
while [ -n "$1" ]
  do
    case "$1" in
      -h ) show_help; exit ;;
      -l ) ACTION=LIST_L; noID=TRUE;;
    -lcr ) ACTION=LIST_CR_PROFILER
            if [ -n "$2" ] ;then
               FOWNER=$2 ; shift
            fi ;;
      -p ) ACTION=LIST_P;;
      -t ) ACTION=LIST_T;;
      -s ) ACTION=LIST_S;;
      -i ) ID=$2; shift;;
      -o ) OCCUR=$2; shift;;
     -oo ) OR_O=TRUE;;
    -oms ) OR_MS=TRUE;;
     -MS ) MS=$2; shift;;
      -u ) FOWNER=$2; S_USER=$2; shift ;;
     -au ) DO_ALTER_SESS="alter session set current_schema=$2;"; shift ;;
     -rn ) ROWNUM=$2; shift ;;
  -purge ) ACTION=PURGE ;noID=TRUE;;
       * ) echo "Invalid option" ;;
    esac
    shift
done
if [ -z "$ID" -a "$ACTION" != "LIST_CR_PROFILER" ];then
   if [ -z "$noID" ];then
         echo " \n --> I need an ID : run dpf -l to see what we have in stock\n"
         exit
   fi
fi

if [ -n "$DO_ALTER_SESS" ];then
   S_USER=SYS
fi

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

if [ "$ACTION" = "LIST_CR_PROFILER" ];then
FOWNER=${FOWNER:-PROFILER}
cat <<EOF

  # ............................................................
  # Run this serie of command to set up the profiler account
  # ............................................................

  @$ORACLE_HOME/rdbms/admin/profload.sql

CREATE USER $FOWNER IDENTIFIED BY $FOWNER DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT connect TO $FOWNER;
grant resource to $FOWNER;


CREATE PUBLIC SYNONYM plsql_profiler_runs FOR $FOWNER.plsql_profiler_runs;
CREATE PUBLIC SYNONYM plsql_profiler_units FOR $FOWNER.plsql_profiler_units;
CREATE PUBLIC SYNONYM plsql_profiler_data FOR $FOWNER.plsql_profiler_data;
CREATE PUBLIC SYNONYM plsql_profiler_runnumber FOR $FOWNER.plsql_profiler_runnumber;

CONNECT $FOWNER/$FOWNER
@$ORACLE_HOME/rdbms/admin/proftab.sql
GRANT SELECT ON plsql_profiler_runnumber TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON plsql_profiler_data TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON plsql_profiler_units TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON plsql_profiler_runs TO PUBLIC;


  # Add this to your package :

DECLARE
  l_result  BINARY_INTEGER;
BEGIN
  l_result := DBMS_PROFILER.start_profiler(run_comment => 'run_' || to_char(sysdate,'YYYYMMDDHH24MISS') );
  .
  .
  .
  l_result := DBMS_PROFILER.stop_profiler;
END;
/
EOF


exit
elif [ "$ACTION" = "PURGE" ];then
   if [ -z "$FOWNER" ];then
        echo "I need an owner : use option -u"
        exit
   fi
   if $SBINS/yesno.sh "to delete from "$FOWNER"  DBMS_PROFILER tables"
     then
       SQL="
delete from plsql_profiler_data;
delete from plsql_profiler_units;
delete from PLSQL_PROFILER_RUNS ;
"
else
  exit
fi
elif [ "$ACTION" = "LIST_P" ];then
SQL=" select exec.cnt/total.cnt * 100 cver
from  (select count(1) cnt
      from plsql_profiler_data d, plsql_profiler_units u
      where d.runid = $ID
      and u.runid = d.runid
      and u.unit_number = d.unit_number)total,
     (select count(1) cnt
      from plsql_profiler_data d, plsql_profiler_units u
      where d.runid = $ID
      and u.runid = d.runid
      and u.unit_number = d.unit_number
      and d.total_occur > 0) exec;
"
elif [ "$ACTION" = "LIST_S" ];then
ORDERBY="order by u.unit_name, u.unit_type, d.line#"
if  [ -n "$OCCUR" ];then
    AND_O=" and d.total_occur >= $OCCUR"
fi
if  [ -n "$MS" ];then
    AND_MS=" and d.total_time >= $MS"
fi
if  [ -n "$OR_O" ];then
    ORDERBY=" order by d.total_occur desc,u.unit_name, u.unit_type, d.line# "
fi
if  [ -n "$OR_MS" ];then
    ORDERBY="order by d.total_time desc,u.unit_name, u.unit_type, d.line# "
fi
SQL="
col text format a120
set lines 190 pagesize 66
col UNIT_OWNER format a16
col UNIT_NAME format a24
col UNIT_TYPE format a12
col TOTAL_OCCUR format 9999999 head Occur
col TOTAL_TIME format 99999999 head MSecs
col ftext format a72 head Text
col line# format 99999
break  on UNIT_OWNER on UNIT_NAME on UNIT_TYPE on report
select * from (
select
    u.unit_name, u.unit_type, d.line#,
   d.total_occur, d.total_time/1000000 total_time,
   (select text from user_source where
    name = upper(u.unit_name)
    and    type = upper(u.unit_type )
    and    line = d.line#
) ftext
from   plsql_profiler_data d, plsql_profiler_units u
                      where  u.runid = $ID
                      and    u.runid = d.runid
                      and    u.unit_number = d.unit_number
                      and unit_owner in (select username from all_users) $AND_O $AND_MS
$ORDERBY
) where rownum <=$ROWNUM
;

"
echo "$SQL"
elif [ "$ACTION" = "LIST_T" ];then
SQL=" select * from (
       select line#, total_occur,
      decode (total_occur,null,0,0,0,total_time/total_occur/1000,0) as avg,
      decode(total_time,null,0,total_time/1000) as total_time,
      decode(min_time,null,0,min_time/1000) as min,
      decode(max_time,null,0,max_time/1000) as max
      from plsql_profiler_data
      where runid = $ID
      order by total_time desc
   )
   where  rownum < $ROWNUM ; "

elif [ "$ACTION" = "LIST_L" ];then
SQL=" column runid format 990
column type format a15
column run_comment format a20
column object_name format a20
column unit_owner format a20

select a.runid,
     substr(b.run_comment, 1, 20) as run_comment,
     a.unit_owner,decode(a.unit_name, '', '<anonymous>',
           substr(a.unit_name,1, 20)) as object_name,
     to_char(RUN_DATE,'YYYY-MM-DD HH24:MI:SS') Run_date,
     TO_CHAR(a.total_time/1000000000, '99999.99') as sec,
     TO_CHAR(100*a.total_time/b.run_total_time, '999.9') as pct
     from plsql_profiler_units a, plsql_profiler_runs b
     where a.runid=b.runid
     order by a.runid asc;"
fi

do_execute
