#!/bin/ksh
# set -xv
# B. Polarski
# 23 Jan 2006
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

# --------------------------------------------------------------------------
function  help
{
 cat <<EOF

   cpl                         # List all invalids objects
   cpl -s                      # show statments to recompile objects
   cpl -d [-u <OWNER>]         # Show last DDL statements

EOF
}
# --------------------------------------------------------------------------
typeset -u fowner
TTITLE='Invalid objects'

while [ -n "$1" ]
do
   case "$1" in
      -h ) help  
           exit ;;
      -s ) CHOICE=CR_SQL   ; TTITLE='show statments to recompile objects';;
      -d ) CHOICE=LAST_DDL ; TTITLE='Show last DDL statements';;
      -u ) fowner=$2 ; shift ; ANDOWNER=" and owner = '$fowner'" ;;
      -v ) set -xv ;;
       * ) FOWNER=$1  ;;
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
if [ "$CHOICE" = "LAST_DDL" ];then

   SQL=" set pagesize 0
         
    select owner,object_name,last_ddl_time,object_type, status from (
         select owner,object_name,to_char(LAST_DDL_TIME,'YYYY-MM-DD HH24:MI:SS') last_ddl_time ,object_type, status
                from dba_objects 
                where OWNER not like 'SYS%'  and object_type not like '%PARTITION' $ANDOWNER  ) 
    order by owner,LAST_DDL_TIME desc "

elif [ "$CHOICE" = "CR_SQL" ];then
   SQL=" set head off
   select 'Alter ' ||
           decode( object_type, 'PACKAGE BODY', 'PACKAGE', 'TYPE BODY', 'TYPE', 'UNDEFINED', 'SNAPSHOT', object_type ) ||
           ' ' || owner || '.' ||
           DECODE(object_type,'JAVA CLASS','"'||dbms_java.longname(object_name)||'"',object_name) || ' Compile ' ||
           decode( object_type, 'PACKAGE', 'SPECIFICATION', 'PACKAGE BODY', 'BODY', 'TYPE BODY', 'BODY', ' ' ) ||
           ';',
           decode( owner, 'SYS', 1, 'SYSTEM', 2, 3) SORT_OWNER,
           decode( object_type, 'VIEW', 1, 'PACKAGE', 2, 'TRIGGER', 9, 3) SORT_TYPE
    from dba_objects
    where status='INVALID' and not (object_type = 'SYNONYM' and owner = 'PUBLIC')
          and   DECODE(UPPER('$fowner'),NULL,'x',owner) like NVL(UPPER('$fowner'),'x')
    union
    select 'Alter public synonym ' || object_name ||' compile ;' ,
           decode( owner, 'SYS', 1, 'SYSTEM', 2, 3) SORT_OWNER,
           decode( object_type, 'VIEW', 1, 'PACKAGE', 2, 'TRIGGER', 9, 3) SORT_TYPE
    from
          dba_objects
    where
          status='INVALID' and  object_type = 'SYNONYM' and owner = 'PUBLIC'
    order by SORT_OWNER, SORT_TYPE
"
else

   SQL="Select owner, object_name, object_type, decode( owner, 'SYS', '1', 'SYSTEM', '2', '3' || owner) A_OWNER,
       decode( object_type, 'VIEW', 1, 'PACKAGE', 2, 'TRIGGER', 9, 3) A_TYPE, status
from dba_objects where  status='INVALID' and   DECODE(UPPER('$fowner'),NULL,'x',owner) like NVL(UPPER('$fowner'),'x')
order by OWNER, object_name"

fi


sqlplus -s "$CONNECT_STRING" <<EOF

set pagesize 0
set linesize 125
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       '$TTITLE - Type cpl -h for help ' nline
from sys.dual
/
set pagesize 0
set head on
col Owner format A30
col object_name format A30
col a_type noprint
col a_owner noprint
col sort_owner noprint
col sort_type noprint
break on owner
$SQL
/

EOF
