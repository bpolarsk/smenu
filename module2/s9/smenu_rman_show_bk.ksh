#!/bin/sh
# set -xv
# program : smenu_rman_show_bk.ksh Author  : bernard Polarski
# Date    : 03-Nov-2005
#           03-Feb-2011  bpa : time to review a bit this old code

# ----------------------------------------------------------------------------------
help()
{
  cat <<EOF

     
     lsbk  
     lsbk   -lp                : List backup from control file
     lsbk   -jb                : List rman bakcup jobs
     lsbk   -jbb               : List last 10 db backup & last 10 arch backup
     lsbk   -bs <BS_KEY>
     lsbk   -f  <BP_KEY>       : List datafile in the backup piece
     lsbk   -cf                : show configuration
     lsbk   -c                 : List backup of controlfiles
     lsbk   -s                 : List backup of spfiles
     lsbk   -asc               : Show last Async backup stats 
     lsbk   -sc                : Show last sync backup stats 
     lsbk   -gap  <arch_seq>   : Show gap in archived backup logs since archive <seq>
     lsbk   -old               : List oldest backup

       -v                 : Verbose mode
      -rn  <nn>           : Display nn rows,  default is 30

EOF
  exit 127
}
# ----------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------
function do_execute
{
sqlplus -s "$CONNECT_STRING" <<EOF
set pagesize 66  linesize 100  termout on pause off  embedded on  verify off  heading off
 select 'MACHINE ' ||rpad(host_name,15,' ') ||' -  ORACLE_SID: $ORACLE_SID ' ||chr(10)||
        'Date                    -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS')|| chr(10)||
        'Username                -  '||rpad(USER,15, ' ') || ' (help: lsbk -h) $TTITLE ' 
from sys.dual, v\$instance v
where v.instance_number = ( select max(instance_number) from v\$instance)

/
set head on
$SQL
EOF
}
# -------------------------------------------------------------------------------------
#                    Main
# -------------------------------------------------------------------------------------

ROWNUM=30
while [ ! -z "$1" ];do
  case "$1" in
        -asc ) CHOICE=ASC ;;
         -sc ) CHOICE=SC ;;
         -bs ) CHOICE=BACKUP_PIECE ; BS=$2; shift ;;
          -c ) CHOICE=CONTROLFILE;;
         -cf ) CHOICE=CONF;;
          -f ) CHOICE=LIST_FILES ; BP=$2; shift;; 
        -gap ) CHOICE=LIST_GAP ; SEQ=$2; shift;; 
         -jb ) CHOICE=JOBS ;; 
         -jbb ) CHOICE=JOBS_BACKUP ;; 
         -lp ) CHOICE=BACKUP_PIECE;;
        -old ) CHOICE=OLD ;;
          -s ) CHOICE=SPFILE;;
          -v ) VERBOSE=TRUE;;
         -rn ) ROWNUM=$2 ; shift ;;
          *  ) help ;;
    
  esac
  shift
done

if [ -z "$CONNECT_STRING" ];then
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} 
   if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
   fi
fi

# ------------------------------------------------------------------------------
if [ "$CHOICE"  = "OLD" ];then
SQL="
set lines 190 pages 300
col bs_incr_type for a8 head 'bk Type'
col file_type format a20
select * from (
select  pkey,file_type, keep, bs_status, to_char(nvl(bs_completion_time,completion_time),'YYYY-MM-DD HH24:Mi') ldate,
      bs_bytes/1024/1024 meg , bs_pieces , bs_incr_type , obsolete,tag
from sys.v_\$backup_files
       order by nvl(completion_time,completion_time) desc
    ) where rownum<=$ROWNUM
/
"
echo "$SQL"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "LIST_GAP" ];then
SQL="
set pages 777
set lines 190
col ldate for a22
spool $SBIN/tmp/list_gap_$SEQ.log
select SEQUENCE#, next_SEQUENCE# ,  
       FROM_DATE, 
        to_char(next_first_time,'YYYY-MM-DD HH24:MI:SS') TO_DATE	,
       next_SEQUENCE# - SEQUENCE# tot_arch_miss
  from (
  select SEQUENCE#, 
     lead(SEQUENCE#) over (order by SEQUENCE#) next_SEQUENCE#, 
     to_char(first_time,'YYYY-MM-DD HH24:MI:SS') FROM_DATE
     , lead(first_time) over (order by first_time) next_first_time 
  from  V\$BACKUP_ARCHIVELOG_DETAILS
  )
  where 
      SEQUENCE# < next_SEQUENCE#-1
  and SEQUENCE# >= $SEQ
  order by SEQUENCE#
/
prompt Result saved in $SBIN/tmp/list_gap_$SEQ.log
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "SC" ];then
SQL="
set lines 190 pages 66
col filename for a50
col ebps head 'IO rate|per sec(mb)' justify c
col meg head 'Size|Meg' for 999999 justify c
col start_time head 'Start |Time' justify c
col end_time head 'End|Time' justify c
col ready head 'Immed|IO request|Served' justify c
col waits head 'IO request| waits' justify c for 99999
col max_wait head 'Max|waits(cs)' justify c for 99999
col tot_w head ' Total|waits(s)' justify c for 99999
col status head 'Status'
select sid,type,status,round(TOTAL_BYTES/1048576) meg ,
     to_char(OPen_time,'YYYY-MM-DD HH24:MI:SS')start_time, to_char(close_time,'HH24:MI:SS') end_time,
       round(EFFECTIVE_BYTES_PER_SECOND/1048576,1)  ebps,
       round(DISCRETE_BYTES_PER_SECOND /1048576,1) avg_rate,
       io_time_total, io_time_max, filename
from V\$BACKUP_SYNC_IO
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "ASC" ];then
SQL="
set lines 190 pages 66
col filename for a50
col ebps head 'IO rate|per sec(mb)' justify c
col meg head 'Size|Meg' for 999999 justify c
col start_time head 'Start |Time' justify c
col end_time head 'End|Time' justify c
col ready head 'Immed|IO request|Served' justify c
col waits head 'IO request| waits' justify c for 99999
col max_wait head 'Max|waits(cs)' justify c for 99999
col tot_w head ' Total|waits(s)' justify c for 99999
col status head 'Status'

select sid,type,status,round(TOTAL_BYTES/1048576) meg , 
     to_char(OPen_time,'YYYY-MM-DD HH24:MI:SS')start_time, to_char(close_time,'HH24:MI:SS') end_time,
       round(EFFECTIVE_BYTES_PER_SECOND/1048576,1)  ebps,
       ready , short_waits+long_Waits waits, greatest(LONG_WAIT_TIME_MAX,SHORT_WAIT_TIME_MAX) max_wait,
       SHORT_WAIT_TIME_TOTAL+LONG_WAIT_TIME_TOTAL/100 tot_w,
       filename
  from V\$BACKUP_ASYNC_IO
  where type != 'AGGREGATE'
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "JOBS_BACKUP" ];then

TTITLE="Last 10 datafiles and archive backup"
SQL="
set lines 200 pages 66
set head on
COLUMN SESSION_RECID   FORMAT 9999999     HEADING 'Sess|Recid'
COLUMN session_key     FORMAT 9999999     HEADING 'Sess|Key'
col Minutes head 'Minutes'
col status for a25
col type for a4

select type, session_key, SESSION_RECID, input_type, In_Size, Out_Size,
         to_char(start_time,'DD-MON-RR HH24:MI')Start_At, 
         to_char(end_time,'DD-MON-RR HH24:MI') End_At, Minutes, status
from (
select 1 ord,'Bkp' type , a.* from (
     select session_key,SESSION_RECID, input_type,
            trunc(input_bytes/1048576) In_Size, trunc(output_bytes/1048576) Out_Size,
            start_time, end_time,
            round(ELAPSED_SECONDS/60) Minutes , status
     from 
            v\$rman_backup_job_details where input_type in ( 'DB INCR'  ,'DATAFILE INCR','DATAFILE FULL')
     order by start_time desc
      ) a where rownum <= 10
union
select 1 ord,'Val' type , a.* from (
     select session_key,SESSION_RECID, input_type,
            trunc(input_bytes/1048576) In_Size, trunc(output_bytes/1048576) Out_Size,
            start_time, end_time,
            round(ELAPSED_SECONDS/60) Minutes , status
     from 
            v\$rman_backup_job_details where input_type in ( 'DB FULL')
     order by start_time desc
      ) a where rownum <= 1
union
select 2,'---', null, null, null, null,null, null, null, null, null from dual
union
select 3 ,'arc' type, b.* from (
     select session_key,SESSION_RECID, input_type,
            trunc(input_bytes/1048576) In_Size, trunc(output_bytes/1048576) Out_Size,
            start_time, end_time,
            round(ELAPSED_SECONDS/60) Minutes , status
     from 
            v\$rman_backup_job_details where input_type = 'ARCHIVELOG'
     order by start_time desc
      ) b where rownum <= 10
)
order by  ord, start_time desc
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "JOBS" ];then

#sqlplus -s "$CONNECT_STRING" <<EOF1
SQL="
set lines 190 pages 66

COLUMN SESSION_RECID   FORMAT 9999999     HEADING 'Sess|Recid'
COLUMN session_key     FORMAT 9999999     HEADING 'Sess|Key'
col Minutes head 'Minutes'

select * from (
     select session_key,SESSION_RECID, input_type,
            trunc(input_bytes/1048576) In_Size, trunc(output_bytes/1048576) Out_Size,
            to_char(start_time,'DD-MON-RR HH24:MI') Start_At,
            to_char(end_time,'DD-MON-RR HH24:MI') End_At,
            round(ELAPSED_SECONDS/60)                  Minutes , status
     from 
            v\$rman_backup_job_details
     order by start_time desc
      ) where rownum <= $ROWNUM
/
"
#EOF1
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "LIST_FILES" ];then
SQL="
   set lines 190 pages 66
   col name for a90
   col BLOCK_SIZE head 'Backuped|size(m)'
   col DATAFILE_BLOCKS head 'File|size(m)'
   col recid for 99999
   select bp.recid key,  bd.FILE# seq#, round(bd.BLOCKS*d.BLOCK_SIZE/1048576,1) BLOCK_SIZE, 
          round(bd.DATAFILE_BLOCKS*d.BLOCK_SIZE/1048576,1) DATAFILE_BLOCKS  
          , DECODE(   bp.status , 'A', 'Available' , 'D', 'Deleted' , 'X', 'Expired') status
          , NAME
   from 
      v\$backup_piece    bp,
      V\$BACKUP_DATAFILE bd,
      v\$datafile d 
   where    
       bp.recid = '$BP'
       and  bd.set_stamp = bp.set_stamp
       and  bd.set_count = bp.set_count
       and d.file#=bd.file# 
  union
  select 
        BTYPE_KEY key , al.SEQUENCE# seq#, 
        decode (nvl(COMPRESSION_RATIO,0), 
                  0, round(al.BLOCKS*al.BLOCK_SIZE/1048576,1),
                 round((al.BLOCKS*al.BLOCK_SIZE/1048576)/COMPRESSION_RATIO,1)
                ) BLOCK_SIZE, 
        round(al.BLOCKS*al.BLOCK_SIZE/1048576,1) DATAFILE_BLOCKS,
        DECODE(   al.status , 'A', 'Available' , 'D', 'Deleted' , 'X', 'Expired', 'U','Unavailable') status,
        'Archive: Start ' || to_char(al.FIRST_TIME,'YYYY-MM-DD HH24:MI:SS') || '  SCN '||to_char(al.first_change#) 
                   ||' --> '|| to_char(al.NEXT_CHANGE#) || ' ' || name name
  from
         V\$BACKUP_ARCHIVELOG_DETAILS ad,
         V\$ARCHIVED_LOG al
  where
         ad.BTYPE_KEY = '$BP' and  BTYPE='BACKUPSET'
    and  al.sequence# = ad.SEQUENCE#
    and  al.THREAD# = ad.THREAD#
    and  al.FIRST_CHANGE# = ad.FIRST_CHANGE#
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "SPFILE" ];then

#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : rman_spfiles.sql                                                |
#-- | CLASS    : Recovery Manager                                                |
#-- | PURPOSE  : Provide a listing of automatically backed up SPFILEs.           |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+


SQL="
SET LINESIZE 190
SET PAGESIZE 9999

COLUMN bs_key                 FORMAT 999999     HEADING 'BS|Key'
COLUMN piece#                 FORMAT 99999    HEADING 'Piece|#'
COLUMN copy#                  FORMAT 9999     HEADING 'Copy|#'
COLUMN bp_key                 FORMAT 999999     HEADING 'BP|Key'
COLUMN spfile_included        FORMAT a11      HEADING 'SPFILE|Included?'
COLUMN completion_time        FORMAT a20      HEADING 'Completion|Time'
COLUMN status                 FORMAT a9       HEADING 'Status'
COLUMN handle                 FORMAT a65      HEADING 'Handle'

BREAK ON bs_key

prompt
prompt Available automatic SPFILE files within all available (and expired) backup sets.
prompt 

select * from (
SELECT
    bs.recid                                               bs_key
  , bp.piece#                                              piece#
  , bp.copy#                                               copy#
  , bp.recid                                               bp_key
  , sp.spfile_included                                     spfile_included
  , TO_CHAR(bs.completion_time, 'DD-MON-YYYY HH24:MI:SS')  completion_time
  , DECODE(   status
            , 'A', 'Available'
            , 'D', 'Deleted'
            , 'X', 'Expired')                              status
  , handle                                                 handle
FROM
    v\$backup_set                                           bs
  , v\$backup_piece                                         bp
  ,  (select distinct
          set_stamp
        , set_count
        , 'YES'     spfile_included
      from v\$backup_spfile)                                sp
WHERE
      bs.set_stamp = bp.set_stamp
  AND bs.set_count = bp.set_count
  AND bp.status IN ('A', 'X')
  AND bs.set_stamp = sp.set_stamp
  AND bs.set_count = sp.set_count
ORDER BY
    bs.recid desc , piece#
) where ROWNUM <= $ROWNUM
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "CONTROLFILE" ];then

#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : rman_controlfiles.sql                                           |
#-- | CLASS    : Recovery Manager                                                |
#-- | PURPOSE  : Provide a listing of automatically backed up control files.     |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+

SQL="
SET LINESIZE 190
SET PAGESIZE 9999

COLUMN bs_key                 FORMAT 999999     HEADING 'BS|Key'
COLUMN piece#                 FORMAT 99999    HEADING 'Piece|#'
COLUMN copy#                  FORMAT 9999     HEADING 'Copy|#'
COLUMN bp_key                 FORMAT 999999     HEADING 'BP|Key'
COLUMN controlfile_included   FORMAT a11      HEADING 'Controlfile|Included?'
COLUMN completion_time        FORMAT a20      HEADING 'Completion|Time'
COLUMN status                 FORMAT a9       HEADING 'Status'
COLUMN handle                 FORMAT a65      HEADING 'Handle'

BREAK ON bs_key


prompt
prompt Available automatic control files within all available (and expired) backup sets.
prompt 

select * from (
SELECT
    bs.recid                                               bs_key
  , bp.piece#                                              piece#
  , bp.copy#                                               copy#
  , bp.recid                                               bp_key
  , DECODE(   bs.controlfile_included
            , 'NO', '-'
            , bs.controlfile_included)                     controlfile_included
  , TO_CHAR(bs.completion_time, 'DD-MON-YYYY HH24:MI:SS')  completion_time
  , DECODE(   status
            , 'A', 'Available'
            , 'D', 'Deleted'
            , 'X', 'Expired')                              status
  , handle                                                 handle
FROM
    v\$backup_set    bs
  , v\$backup_piece  bp
WHERE
      bs.set_stamp = bp.set_stamp
  AND bs.set_count = bp.set_count
  AND bp.status IN ('A', 'X')
  AND bs.controlfile_included != 'NO'
ORDER BY
    bs.recid desc , piece#
) where ROWNUM <= $ROWNUM
/
"
# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "CONF" ];then

SQL="
SET LINESIZE 190
SET PAGESIZE 9999

COLUMN name     FORMAT a48   HEADING 'Name'
COLUMN value    FORMAT a105   HEADING 'Value'

prompt 
prompt All RMAN Configuration Settings that are not default
prompt 

SELECT name , value FROM v\$rman_configuration ORDER BY name
/
"

# ------------------------------------------------------------------------------
elif [ "$CHOICE"  = "BACKUP_PIECE" ];then

if [ -n "$BS" ];then
   AND_BS=" and bp.recid = $BS "
fi


SQL="
-- +----------------------------------------------------------------------------+
-- |                          Jeffrey M. Hunter                                 |
-- |                      jhunter@idevelopment.info                             |
-- |                         www.idevelopment.info                              |
-- |----------------------------------------------------------------------------|
-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : rman_backup_pieces.sql                                          |
-- | CLASS    : Recovery Manager                                                |
-- | PURPOSE  : Provide a listing of all RMAN Backup Pieces.                    |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

SET LINESIZE 190
SET PAGESIZE 9999

COLUMN bs_key              FORMAT 99999         HEADING 'BS|Key'
COLUMN piece#              FORMAT 999           HEADING 'Pce|#'
COLUMN copy#               FORMAT 999           HEADING 'Cpy|#'
COLUMN bp_key              FORMAT 99999         HEADING 'BP|Key'
COLUMN status              FORMAT a9            HEADING 'Status'
COLUMN handle              FORMAT a65           HEADING 'Handle'
COLUMN start_time          FORMAT a14           HEADING 'Start|Time'
COLUMN completion_time     FORMAT a14           HEADING 'End|Time'
COLUMN elapsed_seconds     FORMAT 999,999       HEADING 'Elapsed|Seconds'
COLUMN deleted             FORMAT a8            HEADING 'Deleted?'
column fsize               for 99990.9          head 'size(m)'
col compressed             for a3               head 'Comp|'

BREAK ON bs_key

prompt
prompt Available backup pieces contained in the control file.
prompt Use lsbk -f <BP_PIECE> to view content of the piece
prompt 

select * from (
SELECT
    bs.recid                                            bs_key
  , bp.piece#                                           piece#
  , bp.copy#                                            copy#
  , bp.recid                                            bp_key
  , DECODE(   status
            , 'A', 'Available'
            , 'D', 'Deleted'
            , 'X', 'Expired')                           status
  , compressed
  , handle                                              handle
  , TO_CHAR(bp.start_time, 'mm-dd HH24:MI:SS')       start_time
  , TO_CHAR(bp.completion_time, 'mm-dd HH24:MI:SS')  completion_time
  , bp.elapsed_seconds                                  elapsed_seconds
  , round(bytes/1048576,1) fsize 
FROM
    v\$backup_set    bs
  , v\$backup_piece  bp
WHERE
      bs.set_stamp = bp.set_stamp
  AND bs.set_count = bp.set_count
  AND bp.status IN ('A', 'X') $AND_BS
ORDER BY
    bs.recid desc , piece#
) where rownum <=$ROWNUM
/
"

# ------------------------------------------------------------------------------
else # now runnig DEFAULT

SQL="
-- +----------------------------------------------------------------------------+
-- |                          Jeffrey M. Hunter                                 |
-- |                      jhunter@idevelopment.info                             |
-- |                         www.idevelopment.info                              |
-- |----------------------------------------------------------------------------|
-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
-- |----------------------------------------------------------------------------|
-- | DATABASE : Oracle                                                          |
-- | FILE     : rman_backup_sets.sql                                            |
-- | CLASS    : Recovery Manager                                                |
-- | PURPOSE  : Provide a listing of all RMAN Backup Sets.                      |
-- | NOTE     : As with any code, ensure to test this script in a development   |
-- |            environment before attempting to run it in production.          |
-- +----------------------------------------------------------------------------+

SET LINESIZE 190
SET PAGESIZE 9999

COLUMN bs_key                 FORMAT 999999                 HEADING 'BS|Key'
COLUMN backup_type            FORMAT a13                    HEADING 'Backup|Type'
COLUMN device_type            FORMAT a8                     HEADING 'Device|Type'
COLUMN controlfile_included   FORMAT a11                    HEADING 'Controlfile|Included?'
COLUMN spfile_included        FORMAT a9                     HEADING 'SPFILE|Included?'
COLUMN incremental_level      FORMAT 999999                 HEADING 'Inc.|Level'
COLUMN pieces                 FORMAT 9,999                  HEADING '# of|Pieces'
COLUMN start_time             FORMAT a17                    HEADING 'Start|Time'
COLUMN completion_time        FORMAT a17                    HEADING 'End|Time'
COLUMN elapsed_seconds        FORMAT 999,999                HEADING 'Elapsed|Seconds'
COLUMN tag                    FORMAT a19                    HEADING 'Tag'
COLUMN block_size             FORMAT 99999                  HEADING 'Block|Size'

prompt
prompt Available backup sets contained in the control file.
prompt Includes available and expired backup sets.
prompt 

select * from (
SELECT
    bs.recid                                              bs_key
  , DECODE(backup_type
           , 'L', 'Archived Logs'
           , 'D', 'Datafile Full'
           , 'I', 'Incremental')                          backup_type
  , device_type                                           device_type
  , DECODE(   bs.controlfile_included
            , 'NO', null
            , bs.controlfile_included)                    controlfile_included
  , sp.spfile_included                                    spfile_included
  , bs.incremental_level                                  incremental_level
  , bs.pieces                                             pieces
  , TO_CHAR(bs.start_time, 'mm/dd/yy HH24:MI:SS')         start_time
  , TO_CHAR(bs.completion_time, 'mm/dd/yy HH24:MI:SS')    completion_time
  , bs.elapsed_seconds                                    elapsed_seconds
  , bp.tag                                                tag
  , bs.block_size                                         block_size
  , to_char(bs.KEEP_UNTIL,'YYYY-MM-DD')                   keep_until
  , bs.keep
FROM
    v\$backup_set                           bs
  , (select distinct
         set_stamp
       , set_count
       , tag
       , device_type
     from v\$backup_piece
     where status in ('A', 'X'))           bp
 ,  (select distinct
         set_stamp
       , set_count
       , 'YES'     spfile_included
     from v\$backup_spfile)                 sp
WHERE
      bs.set_stamp = bp.set_stamp
  AND bs.set_count = bp.set_count
  AND bs.set_stamp = sp.set_stamp (+)
  AND bs.set_count = sp.set_count (+)
ORDER BY
    bs.start_time desc, bs.recid
) where rownum <=$ROWNUM
/
"
fi


if [ -n "$VERBOSE" ];then
    echo "$SQL"
fi
do_execute

