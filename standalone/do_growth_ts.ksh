#!/bin/sh

ORACLE_SID=${1:-hprd}
TS=${2:-TS_APK_DATA}
ROWNUM=${3:-2000}

export ORACLE_SID
ORACLE_ADMIN=/oradata/admin
TNS_ADMIN=/oradata/admin
TMPDIR=/tmp
AIXTHREAD_SCOPE=S
HOST=`hostname`

export ORACLE_HOME=/oracle/app
PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_HOME ORACLE_SID ORACLE_BASE TNS_ADMIN ORACLE_ADMIN PATH AIXTHREAD_SCOPE TMPDIR HOST PATH

TARGET_DIR=/oradata/admin/bpo/frg
FRG=$TARGET_DIR/frg_${ORACLE_SID}_`date +%Y%m%d`.txt
FRG_OS=$TARGET_DIR/frg_os_${ORACLE_SID}_${TS}_`date +%Y%m%d`.txt
FRG_CMP=$TARGET_DIR/growth_seg_${ORACLE_SID}_${TS}_`date +%Y%m%d`.txt

case $ORACLE_SID in 
  'hprd'   ) CONNECT_STRING=system/Manager1@hprd ;;
  'tdrprd' ) CONNECT_STRING=system/Manager1@tdrprd ;;
  'bie'    ) CONNECT_STRING=system/SAPbpo_2@bie ;;
esac

(
sqlplus -s  $CONNECT_STRING  <<EOF
ttitle  'MACHINE $HOST          - ORACLE_SID : $ORACLE_SID '   right 'Page:' format 999 sql.pno skip 2
column nline newline
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'FREE - Free space summary by Tablespace  ' nline from sys.dual
/
prompt
set embedded on pagesize 66 linesize 124 heading on
comp sum of nfrags totsiz avasiz on report
break on report

set feed on
column dummy noprint
col name  format         a25 justify c heading 'Tablespace'
col nfrags  format     999,990 justify c heading 'Free|Frags'
col mxfrag  format 9,999,990.0 justify c heading 'Largest|Frag (Megs)'
col totsiz  format 9,999,990.0 justify c heading 'Total|(Megs)'
col avasiz  format 9,999,990.0 justify c heading 'Available|(Megs)'
col pctusd  format         990 justify c heading '%|Used'
col pctusdf format         990 justify c heading '% used| Auto ext'


SELECT /*+ ordered */ h.tablespace_name name, 0 nfrags,0 mxfrag,
       sum(h.bytes_free+h.bytes_used)/1048576 totsiz,
       ROUND ( SUM ( (h.bytes_free + h.bytes_used) - NVL (p.bytes_used, 0)) / 1048576) avasiz,
       ROUND (SUM (NVL (p.bytes_used, 0)) / 1048576)  pctusd, 0 pctusdf
FROM v\$temp_space_header h,
     sys.v_\$Temp_extent_pool p
WHERE p.file_id(+) = h.file_id
      AND p.tablespace_name(+) = h.tablespace_name
GROUP BY h.tablespace_name
union all
select  b.tablespace_name  name,
        nfrags,
        nvl(mxfrag/1048576,0) mxfrag,
        nvl(totbytes/1048576,0) totsiz,
        nvl(freebytes/1048576,0) avasiz,
        decode(b.totbytes,0, 0,round(100-((b.totbytes-(b.totbytes-a.freebytes))/b.totbytes*100),2)) pctusd,
        decode(b.maxbytes,0, 0,round(100-((b.maxbytes-(b.totbytes-a.freebytes))/b.maxbytes*100),2)) pctusdf
from
  (select sum(bytes) freebytes ,tablespace_name from dba_free_space group by tablespace_name) a,
  (select sum(bytes) totbytes, sum(decode(maxbytes,0,bytes,maxbytes)) maxbytes, tablespace_name from  dba_data_files group by tablespace_name)  b,
  (select count(1)  nfrags , max(bytes) mxfrag , tablespace_name from dba_free_space group by tablespace_name) c
where
      b.tablespace_name = a.tablespace_name(+)
  and b.tablespace_name = c.tablespace_name (+)
order by  1
/

EOF

) > $FRG

(
sqlplus -s  $CONNECT_STRING  <<EOF
set pause off pagesize 66 linesize 80 heading off embedded off verify off termout on
ttitle  'MACHINE $HOST          - ORACLE_SID : $ORACLE_SID '   '         Page:' format 999 sql.pno skip 2
column nline newline
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'List object size into tablespace $TS (limited to first $ROWNUM rows) ' nline from sys.dual
/
set linesize 132 head on
col segment_name format a55
col owner format a14
col mb format 99999990 head "Size(mb)"
col tablspace_name format a16
prompt
break on owner on report
comp sum of mb  on report
select s.owner ,
       s.segment_name || (case when s.partition_name is null then ''
                 else '.' || s.partition_name end) as segment_name,
       s.segment_type, s.size_m as mb
from
  (select segment_name , partition_name, owner, bytes/1048576 size_M, segment_type
     from dba_segments where tablespace_name = upper('$TS')  order by size_M desc) s
  where rownum <= $ROWNUM;
EOF
) > $FRG_OS


# produce the report


   f1=`ls -tr $TARGET_DIR/frg_os_${ORACLE_SID}_${TS}*txt | head -1 `
   f2=`ls -tr $TARGET_DIR/frg_os_${ORACLE_SID}_${TS}*txt | head -2 | tail -1 `

if [ ! -f $f1 ];then
   echo "no $f1 file "
   exit
fi
if [ ! -f $f2 ];then
   echo "no $f2 file "
   exit
fi

cat $f1 | expand | sed 's/\.0//' | sed 's/^ //' |  grep -e TABLE -e INDEX -e LOBS | sed 's/TABLE//' | sed 's/INDEX//' | sed 's/LOBSEGMENT//' | sed 's/PARTITION//' | sed 's/[ ][ ]*/ /g' | sed 's/[^ ][^ ]* \([^ ][^ ]*\) \([^ ][^ ]*\)$/ \1 \2 /' | awk '{print "|"$1"| "$2}' | sort > $f1.c
cat $f2 | expand | sed 's/\.0//' | sed 's/^ //' | grep -e TABLE  -e INDEX -e LOBS | sed 's/TABLE//' | sed 's/INDEX//' | sed 's/LOBSEGMENT//' | sed 's/PARTITION//' | sed 's/[ ][ ]*/ /g' | sed 's/[^ ][^ ]* \([^ ][^ ]*\) \([^ ][^ ]*\)$/ \1 \2 /' | awk '{print "|"$1"| "$2}' | sort > $f2.c

(
echo "Date       : `date`"
echo "ORACLE_SID : $ORACLE_SID"
echo "TABLESPACE : $TS"
echo "comparison of `basename $f1` `basename $f2`"
echo
tot_diff=0
cat $f1.c | while read a b c
do
  line=`grep $a $f2.c`
  if [ $? -eq 0 ];then
      # found
      val=`echo $line | awk '{print $2}'`
      if [ $b != $val ];then
          # print only if something change
         name=`echo $line | awk '{print $1}'`
         ldiff=`echo "$val - $b"| bc`
         echo "$a $b $name $val $ldiff" |tr -d '|' | awk '{ printf "%-30s %-10s %-30s %-10s ------> %-10s \n", $1, $2,  $3, $4, $5 }'
         tot_diff=`echo "$tot_diff + $ldiff"| bc`
      fi
  else
      # not found. we substract the amount since we don't find the value anymore
     echo "$a $b "| tr -d '|' | awk '{ printf "%-30s %-10s %-30s %-10s ------> %-10s  \n", $1, $2,  $3 , "", $2 }'
     tot_diff=`echo "$tot_diff - $b" | bc`
  fi
  unset ldiff
done
echo " "
echo "Total diff : $tot_diff mb"
) > $FRG_CMP 2>&1

rm -f $f1.c $f2.c

