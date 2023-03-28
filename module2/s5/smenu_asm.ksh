#!/bin/ksh
# set -xv
# Program : smenu_asm.sh
# Author  : Bernard Polarski
# date    : 09 October 2007
#           with age I become extremly lazy. Most script taken from dbasupport.com 
#           instead of typing mine. I need to be slashed a bit like slaves in pharaonic time
#           in order to revigorate a bit.
#           12 December 2007 added 'asm -mv' to move easily files in ASM from diskgroups
#
HOST=`hostname`
PAR1=$1

function help
{

  cat <<EOF

         adm -f                     # show free space
         asm -d                     # show disk stats
         asm -g                     # List asm disk group
         asm -l                     # show asm files
         asm -a                     # show asm aliases
         asm -slo                   # show long operation on asm
         asm -tpl                   # show templates
         asm -dv                    # show discovered disks
         asm -cli                   # list client db
         asm -p                     # Performance figures on asm disks
         asm -mv <file_id> <DISKGROUP>
      
         -v : verbose


EOF
}
if [ -z "$1" ];then
    help
    exit
fi

while [ -n "$1" ]
do
  case "$1" in
     -a ) CHOICE="ALIAS" ;;
   -cli ) CHOICE="CLIENT" ;;
     -d ) SQL="col path format a50
             col failgroup format a10
             select group_number, disk_number, mount_status, header_status, state, path, failgroup from v\$asm_disk;" ;;
    -dv ) CHOICE="DV" ;;
     -f ) SQL="select group_number, name, total_mb, free_mb, USABLE_FILE_MB,round(USABLE_FILE_MB/free_mb*100,1) pct_free, state, type from v\$asm_diskgroup;" ;;
     -g ) SQL="SELECT group_number,name,state,TOTAL_MB, FREE_MB,USABLE_FILE_MB, BLOCK_SIZE ,REQUIRED_MIRROR_FREE_MB from v\$asm_diskgroup;" ;;
     -l ) CHOICE="FILE" ;;
    -mv ) CHOICE=MV ; FILE_ID=$2; DISKGROUP=$3 ; shift; shift ;;
     -o ) CHOICE=OVERVIEW ;;
     -p ) CHOICE="PERF" ;;
   -slo ) CHOICE="SLO" ;;
   -tpl ) CHOICE="TPL" ;;
     -v ) set -xv ;;
     -h )  help; exit ;;
      * ) help; exit ;;
  esac
  shift
done

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# --------------------------------------------------------
if [ "$CHOICE" = "OVERVIEW" ];then

SQL="
SET serverout on feedback off linesize 200
column instance_name format a20
column db_name format a20
column name format a20
column software_version format a20
column compatible_version format a20
column reads format 999999999
column writes format 999999999
column read_errs format 999999999
column write_errs format 999999999
column read_time format 999999999
column write_time format 999999999
column mb_read format 999999999
column mb_written format 999999999
column state format a20
column total_mb format 999999999
column free_mb format 999999999
column path format a40
column header_status format a20
column redundancy format a20
column mount_status format a20
SET heading off
select '--- CLIENT INFO ---' ci from dual;
SET heading on
select instance_name, db_name, status, software_version, compatible_version from v\$asm_client;
SET heading off
select '*** DISKGROUP INFO ***' di from dual;
SET heading on
select name, state, block_size, type, total_mb, free_mb from v\$asm_diskgroup;
SET heading off
select '*** DISK INFO ***' di from dual;
SET heading on
select name, mount_status, header_status, redundancy, path from v\$asm_disk;
select name, total_mb, free_mb, repair_timer,reads, writes, 
       read_errs, write_errs, read_time, write_time, 
       round(bytes_read/(1024*1024)) mb_read, round(bytes_written/(1024*1024)) mb_written 
from v\$asm_disk;
"
# --------------------------------------------------------
elif [ "$CHOICE" = "MV" ];then
   if [ -z "$DISKGROUP" ];then
      echo "I need a target disk group"
      exit
   fi
   if [ -z "$FILE_ID" ];then
      echo "I need a SOURCE FILE ID "
      exit
   fi
   VAR=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off verify off pagesize 0
select name from v\\$datafile where file#=$FILE_ID;
EOF`
   OLD_FILE=`echo $VAR| awk '{print $1}'`
   if [ -z "$OLD_FILE" ];then 
       echo " did not found file name for file_id=$FILE_ID"
       exit
   fi
   #rman target / <<EOF
   /oraapp01/app/oracle/product/RDBMS/102030/RAC/bin/rman target / <<EOF
BACKUP AS COPY DATAFILE  $FILE_ID format '$DISKGROUP' ;
SQL "ALTER DATABASE DATAFILE $FILE_ID OFFLINE";
SWITCH DATAFILE $FILE_ID to copy ;
RECOVER DATAFILE $FILE_ID ;
SQL "ALTER DATABASE DATAFILE $FILE_ID online " ;
EOF
echo
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++
echo " To purge the file copy from the flash_area connect"
echo " in 'rman target /'  and paste the following command:"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++
echo
echo " delete datafilecopy '$OLD_FILE' ; ";
echo
exit 

elif [ "$CHOICE" = "PERF" ];then
#-- +----------------------------------------------------------------------------+
#-- |                          Jeffrey M. Hunter                                 |
#-- |                      jhunter@idevelopment.info                             |
#-- |                         www.idevelopment.info                              |
#-- |----------------------------------------------------------------------------|
#-- |      Copyright (c) 1998-2007 Jeffrey M. Hunter. All rights reserved.       |
#-- |----------------------------------------------------------------------------|
#-- | DATABASE : Oracle                                                          |
#-- | FILE     : asm_disks_perf.sql                                              |
#-- | CLASS    : Automatic Storage Management                                    |
#-- | PURPOSE  : Provide a summary report of all disks contained within all ASM  |
#-- |           disk groups along with their performance metrics.                |
#-- | NOTE     : As with any code, ensure to test this script in a development   |
#-- |            environment before attempting to run it in production.          |
#-- +----------------------------------------------------------------------------+

SQL="
SET LINESIZE  190 PAGESIZE  9999 VERIFY    off

COLUMN disk_group_name    FORMAT a20               HEAD 'Disk Group Name'
COLUMN disk_path          FORMAT a20               HEAD 'Disk Path'
COLUMN reads              FORMAT 999,999,999       HEAD 'Reads(k)'
COLUMN writes             FORMAT 999,999,999       HEAD 'Writes(k)'
COLUMN read_errs          FORMAT 999,999           HEAD 'Read|Errors(k)'
COLUMN write_errs         FORMAT 999,999           HEAD 'Write|Errors(k)'
COLUMN read_time          FORMAT 999,999,999       HEAD 'Read|Time'
COLUMN write_time         FORMAT 999,999,999       HEAD 'Write|Time'
COLUMN bytes_read         FORMAT 999,999,999,999   HEAD 'Bytes|Read(mb)'
COLUMN bytes_written      FORMAT 999,999,999,999   HEAD 'Bytes|Written(mb)'

break on report on disk_group_name skip 2

compute sum label ''              of reads writes read_errs write_errs read_time write_time bytes_read bytes_written on disk_group_name
compute sum label 'Grand Total: ' of reads writes read_errs write_errs read_time write_time bytes_read bytes_written on report

SELECT
    a.name                disk_group_name
  , b.path                disk_path
  , b.reads/1024               reads
  , b.writes/1024              writes
  , b.read_errs/1024           read_errs 
  , b.write_errs/1024          write_errs
  , b.read_time           read_time
  , b.write_time          write_time
  , b.bytes_read/1048576          bytes_read
  , b.bytes_written/1048576       bytes_written
FROM
    v\$asm_diskgroup a JOIN v\$asm_disk b USING (group_number)
ORDER BY
    a.name;
"
elif [ "$CHOICE" = "ALIAS" ];then
SQL="set linesize 124
-----
-- V$ASM_ALIAS
-- Shows every alias for every disk group mounted by the ASM instance
-----
TTITLE 'ASM Disk Group Aliases (From V\$ASM_ALIAS)'
COL name                FORMAT A28              HEADING 'Disk Group Alias' 
COL group_number        FORMAT 99999            HEADING 'ASM|File #' 
COL file_number         FORMAT 99999            HEADING 'File #'
COL file_incarnation    FORMAT 99999            HEADING 'ASM|File|Inc#'
COL alias_index         FORMAT 99999            HEADING 'Alias|Index'
COL alias_incarnation   FORMAT 99999            HEADING 'Alias|Incn#'
COL parent_index        FORMAT 99999            HEADING 'Parent|Index'
COL reference_index     FORMAT 99999            HEADING 'Ref|Idx'
COL alias_directory     FORMAT A4               HEADING 'Ali|Dir?'
COL system_created      FORMAT A4               HEADING 'Sys|Crt?'
SELECT
     name
    ,group_number
    ,file_number
    ,file_incarnation
    ,alias_index
    ,alias_incarnation
    ,parent_index
    ,reference_index
    ,alias_directory
    ,system_created
  FROM v\$asm_alias
;
"
elif [ "$CHOICE" = "CLIENT" ];then
SQL="set linesize 80
-----
-- V$ASM_CLIENT
-- Shows which database instance(s) are using any ASM disk groups 
-- that are being mounted by this ASM instance
-----
TTITLE 'ASM Client Database Instances (From V\$ASM_CLIENT)'
COL group_number    FORMAT 99999    HEADING 'ASM|File #' 
COL instance_name   FORMAT A32      HEADING 'Serviced Database Client' WRAP 
COL db_name         FORMAT A08      HEADING 'Database|Name'
COL status          FORMAT A12      HEADING 'Status'
SELECT
     group_number
    ,instance_name
    ,db_name
    ,status
  FROM v\$asm_client
;
"
elif [ "$CHOICE" = "DV" ];then
SQL="set linesize 150
-----
-- V$ASM_DISK
-- Lists each disk discovered by the ASM instance, including disks 
-- that are not part of any ASM disk group
-----
TTITLE 'ASM Disks - General Information (From V\$ASM_DISK)'
COL group_number        FORMAT 99999    HEADING 'ASM|Disk|Grp #' 
COL disk_number         FORMAT 99999    HEADING 'ASM|Disk|#'
COL name                FORMAT A20      HEADING 'ASM Disk Name' WRAP
COL total_mb            FORMAT 99999999 HEADING 'Total|Disk|Space(MB)'
COL compound_index      FORMAT 99999999999      HEADING 'Cmp|Idx|#'
COL incarnation         FORMAT 99999999999      HEADING 'In#'
COL mount_status        FORMAT A07      HEADING 'Mount|Status'
COL header_status       FORMAT A12      HEADING 'Header|Status'
COL mode_status         FORMAT A08      HEADING 'Mode|Status'
COL state               FORMAT A07      HEADING 'Disk|State'
COL redundancy          FORMAT A07      HEADING 'Redun-|dancy'
COL path                FORMAT A32      HEADING 'OS Disk Path Name' WRAP
SELECT
     group_number
    ,disk_number
    ,name
    ,total_mb
    ,compound_index
    ,incarnation
    ,mount_status
    ,header_status
    ,mode_status
    ,state
    ,redundancy
    ,path
  FROM v\$asm_disk
;
"
elif [ "$CHOICE" = "FILE" ];then
SQL="-----
-- V$ASM_FILE
-- Lists each ASM file in every ASM disk group mounted by the ASM instance
-----
TTITLE 'ASM Files (From V\$ASM_FILE)'
COL group_number        FORMAT 99999    HEADING 'ASM|File #' 
COL file_number         FORMAT 99999    HEADING 'File #'
COL compound_index      FORMAT 999999999      HEADING 'Cmp|Idx|#'
COL incarnation         FORMAT 999999999      HEADING 'In#'
COL block_size          FORMAT 999999   HEADING 'Block|Size'
COL blocks              FORMAT 999999   HEADING 'Blocks'
COL bytes_mb            FORMAT 999999   HEADING 'Size|(MB)'
COL space_alloc_mb      FORMAT 999999   HEADING 'Space|Alloc|(MB)'
COL type                FORMAT A20      HEADING 'ASM File Type' 
COL redundancy          FORMAT A06      HEADING 'Redun-|dancy'
COL striped             FORMAT A07      HEADING 'Striped'
COL creation_date       FORMAT A12      HEADING 'Created On'
COL modification_date   FORMAT A12      HEADING 'Last|Modified'
SELECT
     group_number
    ,file_number
    ,compound_index
    ,incarnation
    ,block_size
    ,blocks
    ,(bytes / (1024*1024)) bytes_mb
    ,(space / (1024*1024)) space_alloc_mb
    ,type
    ,redundancy
    ,striped
    ,creation_date
    ,modification_date    
  FROM v\$asm_file
;
"
elif [ "$CHOICE" = "TPL" ];then
SQL="-----
-- V\$ASM_TEMPLATE
-- Lists each template present in every ASM disk group mounted 
-- by the ASM instance
-----
TTITLE 'ASM Templates (From V\$ASM_TEMPLATE)'
COL group_number        FORMAT 99999    HEADING 'ASM|Disk|Grp #' 
COL entry_number        FORMAT 99999    HEADING 'ASM|Entry|#'
COL redundancy          FORMAT A06      HEADING 'Redun-|dancy'
COL stripe              FORMAT A06      HEADING 'Stripe'
COL system              FORMAT A03      HEADING 'Sys|?'
COL name                FORMAT A30      HEADING 'ASM Template Name' WRAP
SELECT
     group_number
    ,entry_number
    ,redundancy
    ,stripe
    ,system
    ,name
  FROM v\$asm_template ;
"
elif [ "$CHOICE" = "SLO" ];then
SQL="
-----
-- V$ASM_OPERATION 	
-- Like its counterpart, V$SESSION_LONGOPS, it shows each long-running 
-- ASM operation in the ASM instance
-----
TTITLE 'Long-Running ASM Operations (From V$ASM_OPERATIONS)'
COL group_number        FORMAT 99999    HEADING 'ASM|Disk|Grp #' 
COL operation           FORMAT A08      HEADING 'ASM|Oper-|ation' 
COL state               FORMAT A08      HEADING 'ASM|State'
COL power               FORMAT 999999   HEADING 'ASM|Power|Rqstd'
COL actual              FORMAT 999999   HEADING 'ASM|Power|Alloc'
COL est_work            FORMAT 999999   HEADING 'AUs|To Be|Moved'
COL sofar               FORMAT 999999   HEADING 'AUs|Moved|So Far'
COL est_rate            FORMAT 999999   HEADING 'AUs|Moved|PerMI'
COL est_minutes         FORMAT 999999   HEADING 'Est|Time|Until|Done|(MM)'
SELECT 
     group_number
    ,operation
    ,state
    ,power
    ,actual
    ,est_work
    ,sofar
    ,est_rate
    ,est_minutes  
  FROM v\$asm_operation
;

"
fi
echo
sqlplus -s  "$CONNECT_STRING" <<EOF

column nline newline
column nline2 newline
set pause off pagesize 66 linesize 132 heading off embedded off verify off termout on

select  'Machine           -  '||'${HOST} - ORACLE_SID : ${ORACLE_SID}'  ||
        chr(10)||'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
        'Username          -  '||USER  nline , 'ASM - ASM disk stats'
from sys.dual
/
col name format a20
set head on
$SQL

EOF
