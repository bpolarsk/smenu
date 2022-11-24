#!/bin/sh
  set -xv
# author  : B. Polarski
# program : smenu_create_strmadmin.ksh
# date    : 28 Decembre 2005

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
LEN=70
# -------------------------------------------------------------------------------------
function help 
{

  cat <<EOF

           smenu_create_strmadmin.ksh -u <OWNER> -def_data <DEF TBS> -def_temp <DEF TEMP>        
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
col sb format A9 head "Source|Database"
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
typeset -u fowner
typeset -u fdef_data
typeset -u fdef_temp
if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
   DEST_QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE@$DEST_DB
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STRMADMIN_PASS=${STR_PASS:-STRMADMIN}
EXECUTE=NO
INCLUDE_DML=TRUE
INCLUDE_DDL=FALSE
SRC_DB=$ORACLE_SID
DEST_DB=$DEF_SID
QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE
SRC_QUEUE_NAME=$STRMADMIN.STREAMS_QUEUE
DEST_QUEUE_NAME=${DEST_QUEUE_NAME:-STRMADMIN.STREAMS_QUEUE}


while [ -n "$1" ]
do
  case "$1" in
  -create ) CHOICE=create; TTITLE="Create admin user" ;;
       -u ) fowner=$2 ; shift ;;
-def_data ) fdef_data=$2 ; shift ;;
-def_temp ) fdef_temp=$2 ; shift ;;
       -v ) SETXV="set -xv";;
       -x ) EXECUTE=YES;;
      -len) LEN=$2; shift ;;
        * ) echo "Invalid argument $1"
            help ;;
 esac
 shift
done
#if [  "$CHOICE" = "CREATE_RULE" -o "$CHOICE" = "SWITCH"  -o  "$CHOICE" = "SWITCH_TBL" ];then
#   export S_USER=$frule_owner
#fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# .................................................
# Create a rule with switch ownership
# .................................................
if [ "$CHOICE" = "create" ];then
     SQL="CREATE USER $fowner  IDENTIFIED BY $fowner DEFAULT TABLESPACE "$fdef_data" TEMPORARY TABLESPACE "$fdef_temp"
          ACCOUNT UNLOCK;

GRANT CONNECT, RESOURCE, SELECT_CATALOG_ROLE TO strmadmin;

GRANT EXECUTE ON DBMS_AQADM            TO strmadmin;
GRANT EXECUTE ON DBMS_CAPTURE_ADM      TO strmadmin;
GRANT EXECUTE ON DBMS_PROPAGATION_ADM  TO strmadmin;
GRANT EXECUTE ON DBMS_STREAMS_ADM      TO strmadmin;
GRANT EXECUTE ON DBMS_APPLY_ADM        TO strmadmin;
GRANT EXECUTE ON DBMS_FLASHBACK        TO strmadmin;
GRANT SELECT  ON DBA_APPLY_ERROR       TO strmadmin;

BEGIN
  DBMS_RULE_ADM.GRANT_SYSTEM_PRIVILEGE(
    privilege    => DBMS_RULE_ADM.CREATE_RULE_SET_OBJ,
    grantee      => '$fowner',
    grant_option => FALSE);
END;
/

BEGIN
  DBMS_RULE_ADM.GRANT_SYSTEM_PRIVILEGE(
    privilege    => DBMS_RULE_ADM.CREATE_RULE_OBJ,
    grantee      => '$fowner',
    grant_option => FALSE);
END;
/"
fi
if [ "$EXECUTE" = "YES" ];then
   do_execute
else
  echo "$SQL"
fi
