#!/usr/bin/ksh
# set -xv
# B. Polarski
# 23 Jan 2006
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# --------------------------------------------------------------------------
function  help
{
 cat <<EOF

   ctx -l                         # List all context in system

EOF
}
# --------------------------------------------------------------------------
typeset -u fowner
TTITLE='Invalid objects'

while [ -n "$1" ]
do
   case "$1" in
      -l ) CHOICE=LIST_CTX   ; TTITLE='List context ';;
      -h ) help  ; exit ;;
      -v ) set -x ;;
       * ) help  ; exit ;;
   esac
   shift
done


# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------------------------
if [ "$CHOICE" = "LIST_CTX" ];then

   SQL=" set pagesize 66 lines 190
select NAMESPACE, SCHEMA, PACKAGE, TYPE from dba_context;
"
fi


sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0 linesize 125 termout on pause off embedded on
set verify off heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15,' ')  || '$TTITLE - Type ctx -h for help '
from sys.dual
/
set pagesize 0 head on
break on owner
$SQL

EOF

