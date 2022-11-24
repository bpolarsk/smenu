#!/bin/sh
SQL=smenu_large_object_in_mem

OWNER=
ROWS=
ORDER=" order by 5 desc"
LEN=50
minvalue=0

# ------------------------------------------------------------------------------------
function help
{
     cat <<EOF

          lom -t <num>                  # display <num> caracters  for cursors text
          lom -s <val>                  # limit display objects larger than <num> bytes
          lom -i [-u OWNER]             # List objects in memory that are either pinned or lock
          lom -u <OWNER> [-e|-l|-n]     # restrict display to rows of <OWNER>
               
        Options:       
                   -e      sort by executions  
                   -l      sort by loads 
                   -n      sort by name]

              -r <num> to limit display to <num> rows

EOF
     exit 0
}
# ------------------------------------------------------------------------------------
if [ -z "$1" ];then
     help
fi

while getopts u:s:ielnt:r: ARG
      do
        case  $ARG in
          e ) ORDER=" ORDER by executions desc" ;;
          l ) ORDER=" ORDER by loads desc" ;;
          n ) ORDER=" ORDER by name" ;;
          i ) PINNED=" and pins > 0 or locks > 0 " ;;
          u ) OWNER=" and OWNER = upper('$OPTARG') " ;;
          r ) ROWS=" where rownum < $OPTARG  " ;;
          t ) LEN=$OPTARG ;;
          s ) minvalue=$OPTARG ;;
         *)  help ;;
        esac
     done

cd $SBIN/tmp
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
    sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 80 heading off pause off termout on embedded off verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Shared memory     -  List Objects in memory (help: lom -h)' nline
from sys.dual
/
prompt
prompt
break on owner on report
set embedded on heading on feedback off linesize 150 pagesize 66
col owner        form a13 head 'Owner'
col name         form a40 head 'Name'
col namespace    form a17 head 'Object Name'
col type         form A16 head 'Type'
col sharable_mem form 99999999 head 'Size in |Mem' justify c
col executions   form 999999999 head 'Exec' justify c
col locks        form 99 head 'Lck' justify c
col pins         form 99 head 'Pins' justify c
col kept         form a4 head 'Kept|Mem'
col loads        form 99999 head 'Nbr|Loads'

select owner, name, namespace, type, sharable_mem ,
       loads, executions, locks, pins, kept
       from
          ( select owner, decode(namespace,'CURSOR', substr(name,1,$LEN), name ) name,
                  decode(namespace,'TABLE/PROCEDURE','TABLE/PROC',namespace) namespace,
                  decode(type,'PACKAGE','PKG','PACKAGE BODY','PKG BODY',type) type,
                  sharable_mem , loads , executions, locks,pins,kept
            from
                  v\$db_object_cache
            where
                  sharable_mem  > $minvalue $PINNED $OWNER $ORDER )
$ROWS
/
prompt
prompt
exit

EOF
