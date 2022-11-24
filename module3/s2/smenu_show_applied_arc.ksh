#!/bin/sh
#set -xv
cd $TMP
# ---------------------------------------------------------------------------------
function help 
{
   cat <<EOF


    Display archive info   : 

          apl -a <arch nbr>            # Show archive info whose number is given
          apl -s <SCN>                 # Show archives which contains this SCN
          apl -m                       # Show higher applied up to now, return none if you are a standby db
          apl -n                       # Show filename and SCN instead of time
          apl -rn  <n>                 # List number of line
          apl -d <dest_id>             # restrict output to <dest_id>
          apl -th <n>                  # retrict output to thread# <n>

EOF
exit
}
# ---------------------------------------------------------------------------------
HOSTNAME=`hostname`
NUM=30
DAT_FIELDS=" , FIRST_TIME, NEXT_TIME"
ADD_FIELDS="to_char(FIRST_TIME,'YYYY-MM-DD HH24:MI:SS') ft , to_char(NEXT_TIME,'YYYY-MM-DD HH24:MI:SS') nt, "
while [ -n "$1" ]; do
 case "$1" in
  -a ) FIND_ARCH=TRUE
       ARCH_NUM=$2 
       WHERE="where  SEQUENCE# = $ARCH_NUM"
       shift ;;
   -s ) WHERE="where $2 >= first_change#  and $2 < next_change# " ; 
        shift ;;
   -m ) WHERE="where sequence# = (select max(sequence#) from v\$archived_log where applied ='YES') " ;;
   -d ) WHERE="where dest_id = $2 "  ; shift ;;
  -th ) WHERE="where thread# = $2 "  ; shift;;
   -n ) CHOICE=SHOW_LAST_ARC;;
  -rn ) NUM=$2 ; shift ;;
   -v ) set -xv ;;
   -h ) help ;;
    * ) echo "unknown parameters $1" 
        help ;;
 esac
 shift
done
#S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
ret=`sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 0 head off pause off
select version from v\\$instance;
EOF`
VERSION=`echo $ret | awk -F'.' '{print $1}'`
echo "MACHINE $HOSTNAME - ORACLE_SID : $ORACLE_SID                   Page: 1"

#-------------------------------------------------------------------
if [ "$CHOICE" = "SHOW_LAST_ARC" ];then

    sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 92 termout on heading off pause off termout on embedded off verify off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  ||'   -  Last Archive Logs (apl -h for help)' nline
from sys.dual
/
prompt If 'Name' is empty then the archive is not on disk anymore
prompt
set linesize 190 pagesize 0 heading on embedded on
col name          form A75 head 'Name' justify l
col st    form A14 head 'Start' justify l
col end    form A14 head 'End' justify l
col NEXT_CHANGE#   form 9999999999999 head 'Next Change' justify c
col FIRST_CHANGE#  form 9999999999999 head 'First Change' justify c
col SEQUENCE#     form 9999999 head 'Logseq' justify c
col size_mb for 999999  head 'Size (mb)' justify c

select thread#, SEQUENCE# , to_char(FIRST_TIME,'MM-DD HH24:MI:SS') st,
       to_char(next_time,'MM-DD HH24:MI:SS') End,FIRST_CHANGE#,
       NEXT_CHANGE#, NAME name , size_mb, dest_id
        from ( select thread#, SEQUENCE# , FIRST_TIME, next_time,FIRST_CHANGE#, 
                 NEXT_CHANGE#, NAME name , round((blocks * block_size)/1048576) size_mb , dest_id
                 from v\$archived_log $WHERE order by first_time desc  )
        where rownum <= $NUM
/
EOF
#-------------------------------------------------------------------
else # we are looking to various options

    # ...................................
    if [ "$VERSION" = 8 ];then

   sqlplus -s "$CONNECT_STRING" <<EOF
set heading off embedded off pause off verify off linesize 172 pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  Applied archive logs  (apl-h for help)' nline
from sys.dual
/
set embedded on
set heading on

column  ft            format a21  heading "First time" justify c
column  first_change# format 999999999999
column  next_change#  format 999999999999
prompt
select SEQUENCE#, to_char(FIRST_TIME,'YYYY-MM-DD HH24:MI:SS') ft,
       first_change#, next_change# from ( SELECT SEQUENCE#, FIRST_TIME, first_change#, next_change#
                  FROM V\$log_history ORDER BY SEQUENCE# desc )
   where rownum <= $NUM
/
exit
EOF

    # ...................................
    else

   # VERSION 9+
    sqlplus -s "$CONNECT_STRING" <<EOF
set heading off  embedded off pause off verify off linesize 172 pagesize 66
column nline newline

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Report            -  Applied archive logs (apl -h for help)' nline
from sys.dual
/
set embedded on
set heading on

column  Status format a10     heading "Status" 
column  first_change# format 999999999999
column  next_change#  format 999999999999
column  ft    format a21      heading "First time" justify c
column  nt    format a21      heading "Next time" justify c
column  sta   format a7       heading "Standby|Dest" justify c
column  del   format a7       heading "Deleted|By Rman" justify c
column  dic   format a3       heading "Dic|Beg"
prompt 
select thread#, SEQUENCE#, $ADD_FIELDS
       applied, '    '|| status status, sta, del, registrar,  DICTIONARY_BEGIN Dic, size_mb
    from ( SELECT thread#, SEQUENCE# $DAT_FIELDS $SCN_FIELDS,
                  applied, status, '  '||standby_dest  sta,'  '||deleted del, registrar , DICTIONARY_BEGIN, round((blocks * block_size)/1048576) size_mb
                  FROM V\$ARCHIVED_LOG $WHERE ORDER BY first_time desc)
   where rownum <= $NUM
/

exit
EOF

fi
fi
