#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_run_dbms_repair.ksh
# date    : 9 Decembre 2005

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
LEN=70
# -------------------------------------------------------------------------------------
function help 
{

  cat <<EOF

        dbrep -r  -rt <REPAIR_TABLE> -tbs <TABLESPACE>
        dbrep -c  -rt <REPAIR_TABLE> -o <OBJECT> -s <SCHEMA>
        dbrep -f  -rt <REPAIR_TABLE> -o <OBJECT> -s <SCHEMA> -p <PARTITION>

  note  : 

 DEFAULT for REPAIR TABLE is REPAR_TABLE

        -r : create admin table
        -c : check object
        -f : fix object
EOF

exit
}
# -------------------------------------------------------------------------------------
function do_execute
{
LLEN=`expr 55 + $LEN`
$SETXV
sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 100
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline, '$TTITLE ' nline
from sys.dual
/
set head on

$BREAK
set linesize $LLEN pagesize 30 long 500
col table_name format A18 head "Table name"
prompt 
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------
if [ -z "$1" ];then 
   help; exit
fi

# ............ some default values and settings: .................
typeset -u ftable
typeset -u frepair_table
typeset -u ftable_space
typeset -u fobj
typeset -u fschema
typeset -u fpartition

while [ -n "$1" ]
do
  case "$1" in
       -r ) CHOICE=CR_REPAIR ;;
       -c ) CHOICE=CHECK_OBJ ;;
       -f ) CHOICE=FIX_OBJECT ;;
       -rt) frepair_table=$2 ; shift ;;
       -o ) fobj=$2 ; shift ;;
     -tbs ) ftable_space=$2 ; shift ;;
       -s ) fschema=$2 ; shift ;;
       -p ) fpartition=$2 ; shift ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
      -len) LEN=$2; shift ;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# .................................................
# 
# .................................................
if [ "$CHOICE" = "CR_REPAIR" ];then
   if [ -z "$TABLE_NAME" ];then
      echo="TABLE_NAME ==> \c"
      read $TABLE_NAME
   fi
   echo "TABLESPACE to put $TABLE_NAME ==> \c"
   read TBS
   SQL="execute dbms_repair.admin_tables(table_name=> '$frepair_table', table_type=>dbms_repair.REPAIR_TABLE,
                action=>dbms_repair.CREATE_ACTION, tablespace=>'$ftable_space');"

# .................................................
# 
# .................................................
elif [ "$CHOICE" = "FIX_OBJECT" ];then
    if [ -n "$fpartition" ];then
        P="partition_name => '$fpartition', "
    fi
    SQL=" set serveroutput on size 9999;
declare
  v_cpt integer ;
  begin
   DBMS_REPAIR.FIX_CORRUPT_BLOCKS( schema_name => '$fschema', object_name => '$fobj',  $P fix_count => v_cpt );
   dbms_output.put_line('fix_count => '|| to_char(v_cpt));
END;
/
"

# .................................................
# 
# .................................................
elif [ "$CHOICE" = "CHECK_OBJ" ];then
    unset VAR
    echo "start block ==> \c"
    read VAR
    if [ -n "$VAR" ];then
        BLOCK_START="block_start => $VAR,"
    fi
    unset VAR
    echo "end block ==> \c"
    read VAR
    if [ -n "$VAR" ];then
        BLOCK_START="block_end => $VAR,"
    fi
    SQL=" set serveroutput on size 9999;
declare
  v_cpt integer ;
  begin
   DBMS_REPAIR.CHECK_OBJECT( schema_name => '$fschema', object_name => '$fobj', $BLOCK_START $BLOCK_END corrupt_count => v_cpt );
   dbms_output.put_line('corrupt_count => '|| to_char(v_cpt));
END;
/
"
fi
if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi
