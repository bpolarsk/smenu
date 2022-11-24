#!/bin/ksh
# set -xv
# B. Polarski
# 06 June 2005
# modified  13 April 2006 : added the options  -l and -p
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
TABLE_VIEW=dba_profiles
# --------------------------------------------------------------------------
function help {


     cat <<EOF

       List profiles settings:
       ========================

          prf -l                         # Short list of all profiles
          prf                            # list all profiles  details
          prf  -p <profile name>         # list one profiles  details
          prf  -p <profile name> -lu     # List all user with  this profile
          prf  -lu                       # List all user /  profile

           -l  : list all existing profiles
           -p  : List setting for a single profile
           -lu : list all user wich have profile -p <profile>
EOF
exit
}
# --------------------------------------------------------------------------
SELECT_FIELDS="profile, resource_name, limit, resource_type"
ORDER="order by profile, resource_name"

while [ -n "$1" ]
do
  case "$1" in
     -h ) help ;;
    -lu ) SELECT_FIELDS="distinct username,profile"
          TABLE_VIEW=dba_users 
          ORDER="order by profile";;
     -l ) SELECT_FIELDS="distinct profile"
          ORDER="order by profile";;
     -p ) typeset -u PRF
          PRF=$2
          WHERE="where profile = '$PRF'"
          unset ORDER
          shift ;;
  esac
  shift
done
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi



#cat <<EOF
sqlplus -s "$CONNECT_STRING"  <<EOF
column nline newline
col name format  A16
col value format  A16
set pagesize 66 linesize 124
set termout on pause off verify off heading off
select 'MACHINE ' || lpad('$HOST',8)  || '  -  ORACLE_SID : $ORACLE_SID ' nline,
       'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS') nline,
       'Username          -  '||USER || '  Display profiles attributes ' nline
from sys.dual
/


COL Limit                FORMAT A17      HEADING 'Value'
COL resource_name        FORMAT A25      HEADING 'Attribute'
col profile for a30
prompt RESOURCE_LIMIT must be set on for many LIMIT attribute to be active:
prompt --------------------------------------------------------------------

select name ,':', value from v\$parameter where name = 'resource_limit'
/
prompt
set head on
break on profile

select $SELECT_FIELDS
 from $TABLE_VIEW $WHERE  $ORDER
/
EOF
