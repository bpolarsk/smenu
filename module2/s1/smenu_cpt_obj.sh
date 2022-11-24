#!/bin/ksh
# set -x
#-------------------------------------------------------------------------------
#-- Script:	schema_objects.sql
#-- Purpose:	to count the objects of each type owned by each schema
#-- Copyright:	(c) 2000 Ixora Pty Ltd
#-- Author:	Steve Adams
#__ apapted to smenu by By. Polarski
#-------------------------------------------------------------------------------
function help
{
cat <<EOF

      cpt        # count all user objects
      cpt  -a    # list also user without any objects
      cpt  -dcs  # data dictionary structures
      cpt  -dce  # Data dictionary efficiency

EOF
exit
}
OWNER=''
while [ -n "$1" ]
do
  case "$1" in
     #-a ) ALL_U="(+) and u.type#=1" ;;
     -a ) ALL_U="(+) " ;;
     -dcs ) DCS="TRUE" ;;
     -dce ) DCE="TRUE" ;;
     -h ) help ;;
      * ) OWNER=" u.username = upper('$1') and " ;;
  esac
  shift
done
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
USER=`echo $USER | $NAWK '{ print toupper($1) }'`

#S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi


if [ -n "$DCE" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

clear screen
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on
set heading off pause off
set embedded off
set verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  Displays detail data for the data dictionary' nline
from sys.dual
/
set embedded on
set heading on
set feedback off
set linesize 132 pagesize 66

col parameter heading 'Parameter Name'    format a20       justify c trunc
col count     heading 'Entries|Allocated' format 9999990   justify c
col usage     heading 'Entries|Used'      format 9999990   justify c
col gets      heading 'Gets'              format 999999990   justify c
col modifications heading 'Modification'  format 999999990   justify c
col getmisses heading 'Get|Misses'        format 999999990   justify c
col pctused   heading 'Pct|Used'          format     990.0 justify c
col pctmisses heading 'Pct|Misses'        format     990.0 justify c
col action    heading 'Rec''d|Action'     format a6  justify c

select
  parameter,
  count,
  modifications,
  usage,
  100*nvl(usage,0)/decode(count,null,1,0,1,count) pctused,
  gets,
  getmisses,
  100*nvl(getmisses,0)/decode(gets,null,1,0,1,gets) pctmisses,
  decode(
    greatest(100*nvl(usage,0)/decode(count,null,1,0,1,count),80),
    80, ' Lower',
    decode(least(100*nvl(getmisses,0)/decode(gets,null,1,0,1,gets),10),
    10, '*Raise', ' Ok')
  ) action
from
  v\$rowcache
order by
  1
/

exit

elif [ -n "$DCS" ];then
sqlplus -s "$CONNECT_STRING" <<EOF

clear screen
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66  linesize 80  heading off pause off termout on  embedded off verify off feed off 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List              -  Displays info on the data dictionary' nline
from sys.dual
/
set embedded on
set heading on
set feedback off
set linesize 132 pagesize 66

prompt -----------------------------------------------------------------------------------------

prompt .              Set dsiplay to 132 column as it is a big report
prompt Cache# - Row cache ID number.
prompt Type - Parent or Subordinate row cache type.
prompt Subordinate# - subordinate set number.
prompt Parameter    - Name of the INIT.ORA parameter that determines
prompt .              the number of entries in the data dictionary cache (V6)
prompt Count        - Total number of entries in the data dictionary cache.
prompt Usage        - Number of cache entries that contain valid data.
prompt Fixed        - Number of fixed entries in the cache.
rem Gets            - Total number of requests for information.
rem Get Misses      - Number of data requests resulting in cache misses.
rem Scans           - Number of scan requests.
rem Scan Misses     - Number of times a scan failed to find the data in the cache.
rem Scan Completes  - For a list of subordinate entries, the number of times
rem .                 the list was scanned completely.
rem Modifications   - Number of inserts, updates, and deletions.
rem Flushes         - Number of times flushed to disk.

prompt -----------------------------------------------------------------------------------------

prompt

column parameter format a25
column cache#         format 99,990 heading "Cache#" justify center
column type          format 99,990 heading "Type"
column subordinate   format 990 heading "Subordinate"
column count         format 9,99,990 heading "Total|Entries"
column usage         format 99,990 heading "Valid|Entries"
column fixed         format 9,990 heading "Fixed|Entries"

select
cache#,
type,
subordinate#,
parameter,
count,
usage,
fixed
from v\$rowcache
order by cache#,subordinate#,parameter
/
exit

EOF

else # default
sqlplus -s " $CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 120 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Schema Objects' from sys.dual
/   

set heading on
column username format a24 trunc heading SCHEMA
column cl format 99999 heading CLSTR
column ta format 99999 heading TABLE
column ix format 99999 heading INDEX
column se format 9999 heading SEQNC
column tr format 9999 heading TRIGR
column fn format 9999 heading FUNCT
column pr format 99999 heading PROCD
column pa format 9999 heading PACKG
column vi format 99999 heading VIEWS
column sy format 99999 heading SYNYM
column ot format 9999999 heading OTHER
rem break on report
compute sum of cl ta ix se tr fn pr pa vi sy ot on report

select
  u.username,
  sum(decode(o.type, 'CLUSTER', objs))  cl,
  sum(decode(o.type, 'TABLE', objs))  ta,
  sum(decode(o.type, 'INDEX', objs))  ix,
  sum(decode(o.type, 'SEQUENCE', objs))  se,
  sum(decode(o.type, 'TRIGGER', objs)) tr,
  sum(decode(o.type, 'FUNCTION', objs))  fn,
  sum(decode(o.type, 'PROCEDURE', objs))  pr,
  sum(decode(o.type, 'PACKAGE', objs))  pa,
  sum(decode(o.type, 'VIEW', objs))  vi,
  sum(decode(o.type, 'SYNONYM', objs))  sy,
  sum(decode(o.type, 'CLUSTER',0, 'TABLE',0,  'INDEX',0, 'SEQUENCE',0, 'TRIGGER',0, 'FUNCTION',0, 'PROCEDURE',0, 'PACKAGE',0, 'VIEW',0, 'SYNONYM',0, objs))  ot
from
(select owner, object_type type, count(*) objs from dba_objects group by owner, object_type ) o,
 dba_users u
where $OWNER
  u.username = o.owner $ALL_U
group by
  u.username
order by
  decode(u.username, 'SYS', 1, 'SYSTEM', 2, 'PUBLIC', 3, 4),
  u.username
/
EOF
fi
