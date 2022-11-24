#!/bin/sh
#  set -xv
# author  : B. Polarski
# program : smenu_gather_stat_tbl.ksh
# date    : 01 October 2005
# Apapted to Smenu by B. Polarski
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -----------------------------------------------------------------------------------------------------------------------
function help
{

cat  <<EOF 
     Gather statistics utility: This script output on the screen the gather statistics statement.  You can execute it if you add -x

     sta -u <OWNER> -t <TABLE>  [-p <Percent>] [-f] [-s <stattab>] [-o <stat owner>] [-n <statid>]
         -part [partname] -c -cl -cp -x -ka <num buckets>  -size <n> -skew -kc <string> -lock|-unlock [-opt <AUTO>]
     sta -u <OWNER> -i <INDEX>  [-p <Percent>] [-s <stattab>] [-o <stat owner>] [-n <statid>] -part [partname] -cp -cl -x
     sta -del -t <TABLE> -u <OWNER> 
     sta -get -u <OWNER> -t <TABLE> [-part <partname>]
     sta -lc
     sta  -u <OWNER> -t <TABLE> -set_freq -ar "'name1','name2'" -av '100,50'

            -p : Percent sample on each objects (default to 5%)  -part   : Partition name      -i : the index    
            -t : the table      -d   : degree (default to 2x cpu)      -o : <stat owner> can be different than the objects analyzed              
            -f : Copy gathered statistics to sm_stattab. It is needed if you intend to export/import statistics 
            -c : Set cascade=TRUE to gather statistics also on the indexes
            -g : granularity, values are :    DEFAULT         Gather global - and partition-level statistics
                                              PARTITION, SUBPARTITION, GLOBAL, ALL Gather all (subpart, part, and global)
            -u : the table(s) or index(es) owner. If only the owner is given, then gather stats for schema
          -opt : Use -option. AUTO will gather stats with option 'GATHER AUTO' Gathers all necessary statistics automatically
            -v : verbose                                        -x : execute the output of this scripts
          -del : Delete stats for a table        
           -lc : List table with table statistics locked

Set/get Segment statistics: 
---------------------------

          -get     : Get object statistics   :   sta -get  -t <TABLE> -u <OWNER>  -col <COLUMN_NAME> [-part<partname>]
          -set_tbl : Set segment level statistics :   -numrows <nn>  -numblks <nn> -avgrlen <nn>
          -set_col : Set column  level statisitcs :   -distinct <nn> -nullcnt <nn> -density <nn>
          -set_freq : Set column  histogram frequence
                      -ar "name1,name2,..."  -av "val1,val2,..." where both list have equal nbr members.
                      no space, comma separated. Each val in -av is the value for the corresponding in -ar

     -cr_histo : creat frequency histogram limited to max 254 first buckets orderedb by tbl.col count desc
               -cpt <ncpt> : only included table.col with nbr count >= ncpt
    

    example : sta -cr_histo -u scott -t emp -col depno -cpt 2             # create an frequency histogram on scott.emp 
                                                                            for all depno with more than one empno.
             sta -u system -t TOTO -col SWIACT_TDR -set_freq -ar "'N','Y'" -av "154,500000"
Misc:              sta -lr |-mod <n> [-u<OWNER>] [-t <TABLE>]
-----
                 -lr : List last run of job dbms_gather_stat    
               -mod  : List table whose stats are stale and not anaylized since <n> days while they have been modified
               -lst  : list stale statistics
      -lock|-unlock  : if table name is not given then lock/unlock stats at schema level
              -def   : list dbms_gather_stats default parameters

Method opts params:
-------------------
    -ka : For table only; set the number of histogram buckets for all columns: -k 100
    -kc : For table only; set the number of histogram buckets per each columns. Give the string list used by method_opt
  -size : Number of buckets  method_opt                                -skew    : Use Skew as argument for method_opt
          -col <columns name> ..... -col <columns name> gather stats only for columns name list

Note :   sta -fy start -int 10               # Start gathering system stat during the 10 next minutes 
------   sta -u <user> -l -s <stattab>       # Give types per object.
         sta -u <user> -t <tbl> -kc "for columns <col> size 240"  -p 100 # to give your own method ops
       or
         sta -u <user> -t <tbl>  -col BANKACCOUNT_ID -size 250 -x    # Use: 'tbl [-u <user>] -t <table> -s' for all column stats
    
System statistics:           sta -fx | -dx/-dy     OR      sta -fy [start |stop] [-int <minutes>]
------------------
    -fx : gather stat for fixed tables                                   -dx     : delete stat for fixed tables
    -fy : gather system statistics                                       -dy     : delete system statistics 
     -y : export or import will also do system statistics                -lp     : List dbms_stat default parameters

Imp/Export statistics:      sta -e -u <OWNER> -y      
----------------------      sta -e -s <stattab> -f [-t <TABLE>] [-i <INDEX>] [-u <OWNER>] -c

     -e : export stats to <stattab> from schema -u <OWNWER>, from table -t <TABLE> or from index -i <INDEX>
     -a : import stats from <stattab> into schema -u <OWNWER> or into table -t <TABLE> or -i <INDEX> -n <statid>
     -s : <stattab> Table that will hold stat of the table. (default is sm_stattab)

Tables statistics:      sta -del -s  <stattab> [-t <TABLE>] [-i <INDEX>] [-u <OWNER>] -c
------------------      sta -a -s <stattab> [-t <TABLE>] [-i <INDEX>] [-u <OWNER>] -c -n <statid> -o <statowner>
                        sta -u <OWNER> -l |-m  [-s <stat table>] [-b <TABLESPACE>]
                        sta -cr_histo [-u <OWNER>] -t <Table> -col <COL> [-cpt <ncpt>]

   -del : delete stats from <stattab> and schema -u <OWNWER> -n <statid>
                -t <TABLE>  -part [partname] -cp -cl -ci
                      -cp :  delete cascade to partitions if partname is NULL -cl :  delete cascade to columns -ci :  delete cascade to indexes
                -i <INDEX> -part [partname]  -cp
     -l : list existing stat table and statid. With -s <stattab>, gives details per type for each object
     -m : Create stat table given by -s <table stat> -b <TABLESPACE> create stattable in TABLESPACE otherwise default is used
     -n : statid

EOF

exit
}
# -----------------------------------------------------------------------------------------------------------------------
if [ -z "$1" ];then
   help; exit
fi
typeset -u ftable
typeset -u findex
typeset -u fowner
typeset -u fgran
typeset -u fcasc
typeset -u fstattatb
typeset -u FVAR
typeset -u COL_LIST
unset l_part
CHECK_STR="#DEFAULT#PARTITION#SUBPARTITION#GLOBAL#ALL#"
CREATE_STATTAB=FALSE
LIST_STAT=FALSE
EXECUTE=FALSE
EXPORT_STAT=FALSE
IMPORT_STAT=FALSE
STAT_SYSTEM=FALSE
fdate=`date +%m%d%H%M`
fperc=dbms_stats.auto_sample_size
fgran='ALL'
fcasc=FALSE
fdegree=`$SBIN/module2/s1/smenu_list_init_param.sh -p parallel_degree_limit`
if [ -z "$fdegree" ];then
   fcpu=`$SBIN/module2/s1/smenu_list_init_param.sh -p cpu_count`
   fdegree=`expr $fcpu \* 2`
fi
while  [ -n "$1" ]
do

  case "$1" in
   -a ) IMPORT_STAT=TRUE;;
  -ar ) VAR_ARRAY=$2 ; shift ;;
  -av ) VAL_ARRAY=$2 ; shift ;;
   -b ) FVAR=$2
        TBS=", '$FVAR'"
        shift ;;
   -c ) fcasc=TRUE  ;;
  -cl ) DEL_CASC_COL=",cascade_columns => TRUE ";;
  -cp ) DEL_CASC_PART=",cascade_parts => TRUE ";;
 -cpt ) NMAX=$2 ; shift ;;
 -col ) if [ -n "$COL_LIST" ];then
             COL_LIST="${COL_LIST}, $2"
        else
             COL_LIST="$2"
        fi
        shift ;;
-cr_histo ) CHOICE=SET_HISTO;;
   -d ) fdegree=$2 ; shift ;;
 -def ) CHOICE=DEF ;;
 -del ) fdel=TRUE  ; EXECUTE=NO;;
  -dx ) CHOICE=GFIX ; GET=FALSE;;
  -dy ) CHOICE=GSYS ; GET=FALSE ;;
   -e ) EXPORT_STAT=TRUE; COPY_ST_STTAB=TRUE;;
   -f ) COPY_ST_STTAB=TRUE ;;
  -fx ) CHOICE=GFIX ; GET=TRUE;;
  -fy ) CHOICE=GSYS ; GET=TRUE 
        if [ "$2" = "-x" -o -z "$2" ] ;then
              :
         else
            MODE=$2; shift 
         fi;;
   -g ) fgran=$2
        if [ -n "${CHECK_STR##*$fgran*}" ];then
          echo "########################################"
          echo  "Wrong granularity value "
          echo "########################################"
          echo  "\n Must be in ; \n`echo $CHECK_STR |tr '#' '\n'`"
          help
        fi
        shift;;
 -get ) CHOICE=GET_STATS ; EXECUTE=YES;;
   -i ) findex=$2 ; shift ;;
 -int ) INT_MINUTES=$2; shift ;;
  -ka ) METHOD_OPT=" ,method_opt=>'for all columns size $2'";shift ;;
  -kc ) METHOD_OPT=" ,method_opt=>'$2'";shift ;;
   -l ) LIST_STAT=TRUE ;;
  -lc ) CHOICE=LIST_LOCK  ;;
  -lr ) CHOICE=LIST_LAST_RUN ; fower=${S_USER:-SYS};;
  -lp ) CHOICE=LIST_PARAM ;;
 -lst ) CHOICE=LIST_STALE ;;
   -m ) CREATE_STATTAB=TRUE  ;;
 -mod ) CHOICE=LIST_NOT_ANALYZED_TBL
        if [ -n "$2" ];then
            if [ "$2" = "-u" -o "$2" = "-t" ];then
                :
            else
               NDAYS=$2 ; shift
            fi
        fi ;;
   -n ) l_fstatid=$2 ; shift ;;
   -o ) fstat_owner=$2 ; shift ;;
 -opt ) OPTIONS=OPTIONS ; OPT_VAR=AUTO; shift ;;
   -p ) fperc=$2 ; shift ;;
-part ) l_part=$2 ; shift ;;
   -s ) l_fstattab=$2 ; shift ;;
 -set_tbl ) CHOICE=SET_TBL_STAT ;;
 -set_col ) CHOICE=SET_COL_STAT ;;
-distinct ) SET_DISTINCT=$2; shift ;;
 -nullcnt ) SET_NULLCNT=$2 ; shift ;; 
 -density ) SET_DENSITY=$2 ; shift ;;
 -numrows ) SET_NUMROWS=$2 ; shift ;;
 -numblks ) SET_NUMBLKS=$2 ; shift ;;
 -avgrlen ) SET_AVGRLEN=$2 ; shift ;;
-size ) CSIZE=$2; shift ;;
-set_freq ) SET_FREQ=TRUE ;;
-skew ) SKEW=SKEW;;
   -t ) ftable=$2 ; shift ;;
   -u ) fowner=$2 ; shift ;;
   -v ) set -x ;;
   -x ) EXECUTE=TRUE ;;
   -y ) STAT_SYSTEM=TRUE ;;
  -lock ) LOCK=TRUE ; unset UN ;;
-unlock ) LOCK=TRUE ; UN=UN ;;
   -h ) help;;
   * )  echo "Invalid argument $1"
        $help ;;
 esac
 shift
done

# -------------------------------------------------------------------------------------
function ret_part
{
   arg=$1
   cpt=$2
   TYPE=$3        # value is TAB or IND
   if [ $cpt -gt 0 -a ! "$fgran" = "PARTITION" ];then
       case $arg in
         PART_NAME ) echo SUBPARTITION_NAME |tr -d '\r' ;;
         DBA_TAB   ) echo DBA_${TYPE}_SUBPARTITIONS |tr -d '\r' ;;
       esac
       if [ "$fgran" = "ALL" -o "$fgran" = "SUBPARTITION" ];then
          :
       else
          echo "Garther stats for subpartitions are only done for Granularity = \"ALL\" or \"SUBPARTITION\""
          echo "If you are not happy with that, you can send your instults at ceo@Oracle.com"
          echo "Aborting ==>"
          exit 0
      fi
   else
     case $arg in
        PART_NAME ) echo PARTITION_NAME |tr -d '\r' ;;
        DBA_TAB   ) echo DBA_${TYPE}_PARTITIONS |tr -d '\r' ;;
     esac
   fi
}
# -------------------------------------------------------------------------------------
function get_ind_nbr_part
{
      var=`sqlplus -s "$CONNECT_STRING"<<EOF
      set pagesize 0 feed off head off pause off
      select max(subpartition_count) from dba_ind_partitions where index_owner = '$fowner' and index_name = '$findex' ;
EOF`
      if [ -z "$var" ];then
         echo 0
      else
        echo "`echo $var |tr -d '\r' | awk '{print $1}'`"
      fi
}
# -------------------------------------------------------------------------------------
function do_execute
{
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66  linesize 100  termout on pause off  embedded on  verify off  heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Execute DBMS_STATS ' nline
from sys.dual
/

set head off PAGESIZE 0
set linesize 124
Prompt Running $FIL_EXECUTE
@$FIL_EXECUTE
/
EOF
echo '********************************************************************'
echo "log file: $FOUT"
echo '********************************************************************'
echo
}
# -------------------------------------------------------------------------------------
function get_tab_nbr_part
{
   # normal table return -1, partition, return 0, subpartition return count(subpartitions)
   var=`sqlplus -s "$CONNECT_STRING"<<EOF
     set pagesize 0 feed off head off pause off
     select nvl(max(subpartition_count),-1) from dba_tab_partitions where table_owner = '$fowner' and table_name = '$ftable' ;
EOF`
   if [ -z "$var" ];then
       echo 0
   else
     echo "`echo $var |tr -d '\r' | awk '{print $1}'`"
   fi
}
# -------------------------------------------------------------------------------------
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# -------------------------------------------------------------------------------------
# -------------------------------     Main     i---------------------------------------
# -------------------------------------------------------------------------------------
# ................................................
# set_histogram
# ................................................
if [ "$SET_FREQ" = "TRUE" ];then
  BK_COUNT=`echo $VAR_ARRAY  |  awk 'BEGIN{FS=","} {print NF}'`
  fpart=${l_part:-NULL}
  if [ -n "$fpart" ];then
       FPART=" partname => '$fpart',"
  fi
SQL="
 declare
    m_ownanme       varchar2(30):='$fowner';
    m_tabname       varchar2(30):='$ftable' ;
    m_colname       varchar2(30):='$COL_LIST' ; -- should contain only one value for this option
    m_distcnt       number;
    m_density       number;
    m_nullcnt       number;
    srec            dbms_stats.statrec;
    m_avgclen       number;
    c_array         dbms_stats.chararray ;
    n_array         dbms_stats.numarray ;
 
begin
 
    
   dbms_stats.get_column_stats(
        ownname     => '$fowner',
        tabname     => '$ftable', $PART
        colname     => '$COL_LIST',
        distcnt     => m_distcnt,
        density     => m_density,
        nullcnt     => m_nullcnt,
        srec        => srec,
        avgclen     => m_avgclen
    );
 
    c_array     := dbms_stats.chararray($VAR_ARRAY);
    srec.bkvals := dbms_stats.numarray($VAL_ARRAY);
    srec.epc    := $BK_COUNT;
 
    dbms_stats.prepare_column_values(srec, c_array);
 
    dbms_stats.set_column_stats(
        ownname     => '$fowner',
        tabname     => '$ftable', $PART
        colname     => '$COL_LIST',
        distcnt     => m_distcnt,
        density     => m_density,
        nullcnt     => m_nullcnt,
        srec        => srec,
        avgclen     => m_avgclen
    );
 
end;
/

set lines 190 pages 66
col low_value for a30
col high_value for a30
select
    num_distinct, low_value, high_value, density, num_nulls, num_buckets, histogram
from
    dba_tab_columns
where
    table_name = '$ftable' and owner= '$fowner' and column_name = '$COL_LIST'
/
 
select
    endpoint_value, endpoint_number,
    lag(endpoint_number,1) over( order by endpoint_number) prev_number
from
    dba_tab_histograms
where
    table_name = '$ftable' and owner= '$fowner' and column_name = '$COL_LIST'
order by
    endpoint_value
/
"
echo "$SQL"
if [ "$EXECUTE" = "TRUE" ];then
   sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
EOF
fi
exit
# ................................................
# LOCK/UNLOCK stats
# ................................................
elif [ "$LOCK" = "TRUE" ];then
  
  if [ -z "$ftable" ];then
      SQL=" prompt doing exec dbms_stats.${UN}LOCK_SCHEMA_STATS ('$fowner');;
            exec dbms_stats.${UN}LOCK_SCHEMA_STATS ('$fowner');"
  else
     SQL="prompt doing exec dbms_stats.${UN}LOCK_TABLE_STATS ('$fowner','$ftable');;
      exec dbms_stats.${UN}LOCK_TABLE_STATS ('$fowner','$ftable');"
   fi
sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
EOF
exit
fi
# ......................................................................
# Create user defined histogram
# ......................................................................
if [ "$CHOICE" = "SET_HISTO" ];then
#  This procedure works very well in 10g but only for SQL with litterals. Creating an histogram for SQL with binds,
#  will not work: only the first execution will consider the histogra. Then the same plan is used until 
#  the cursor is cleared from memory. Having the optimizer probe the binds against the histogram for each SQL execution
#  is called 'Adaptative cursor sharing' and it is in 11g.
# 
NMAX=${NMAX:-100}
SQL="
set serveroutput on   lines 32000
declare

    srec                      dbms_stats.statrec;
    a_bucket                  dbms_stats.numarray;
    v_tot_rows_not_in_freq    number;
    v_tot                     number;
    v_density                 number;
    v_distinct_key_not_in_freq   number;
    v_cutoff_value            number:=$NMAX;
begin
     -- create the histogram, maximum 254 buckets but may be lower following v_cutoff_value
     select cpt, USERIDENTITY_ID bulk collect into srec.bkvals, a_bucket from (
     select
          cpt, USERIDENTITY_ID 
     from ( select count(*) cpt, $COL_LIST
                              from $fowner.$ftable
                                   group by $COL_LIST order by count(*) desc
          )
     where rownum <= 254 and cpt > v_cutoff_value order by USERIDENTITY_ID
    );

    -- Calculate now the density for all values which are not in the histo.
    -- the density is calculated from all rows not in the frequency histogram
    -- Cut off value to be taken into the histogram is set by default to 150, adapt following needs

    -- so density =   (tot rows not in freq / distinct key not in freq)/tot row in table)
    with v as (select useridentity_id
            from ( select useridentity_id
                             from $fowner.$ftable
                                 group by $COL_LIST having count(*) > 150  order by count(*) desc)
             where rownum <=254 
         )
    select sum(cpt),count(useridentity_id) into v_tot_rows_not_in_freq, v_distinct_key_not_in_freq
        from ( select 
                      count(*) cpt,  useridentity_id
               from  
                      $fowner.$ftable  b
                where not exists 
                       (select null from v where v.useridentity_id= b.useridentity_id)
                group by useridentity_id) ;
  
    select count(*) into v_tot from $fowner.$ftable; 

    -- The density we set here is to be used by optimizer for all values that are not in frequency histogram
    v_density:=((v_tot_rows_not_in_freq/v_distinct_key_not_in_freq)/v_tot); 

    dbms_output.put_line(
                'Rows in table                  : ' || to_char(v_tot) || chr(10) ||
                'distint Keys in histogram      : ' || to_char(a_bucket.count) || chr(10) ||
                'Tot Rows keys covered by histo : ' || to_char(v_tot-v_tot_rows_not_in_freq) || chr(10)||
                'Distinct Keys not in histogram : ' || to_char(v_distinct_key_not_in_freq) || chr(10) ||
                'Rows not in histogram          : ' || to_char(v_tot_rows_not_in_freq) || chr(10)||
                'Density for keys not in histo  : ' || trim(to_char(v_density,'990.9999999999')) );

    srec.epc:=a_bucket.count   ;

    dbms_stats.prepare_column_values(srec, a_bucket);
    dbms_stats.set_column_stats(
        ownname     => '$fowner',
        tabname     => '$ftable',
        colname     => '$COL_LIST',
        density     => v_density,
         srec        => srec );
end;
/
"
echo "$SQL"
if [ "$EXECUTE"  = "TRUE" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed on pause off verify on
$SQL
EOF
fi
exit
# ......................................................................
elif [ "$CHOICE" = "DEF"  ]; then
    sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off
select
'AUTOSTATS_TARGET : ' || dbms_stats.get_prefs('AUTOSTATS_TARGET' ) AUTOSTATS_TARGET,
'CASCADE          : ' || dbms_stats.get_prefs('CASCADE' ) CASCADE,
'DEGREE           : ' || dbms_stats.get_prefs('DEGREE' ) DEGREE,
'ESTIMATE_PERCENT : ' || dbms_stats.get_prefs('ESTIMATE_PERCENT' ) ESTIMATE_PERCENT,
'METHOD_OPT       : ' || dbms_stats.get_prefs('METHOD_OPT' ) METHOD_OPT,
'NO_INVALIDATE    : ' || dbms_stats.get_prefs('NO_INVALIDATE' ) NO_INVALIDATE,
'GRANULARITY      : ' || dbms_stats.get_prefs('GRANULARITY' ) GRANULARITY,
'PUBLISH          : ' || dbms_stats.get_prefs('PUBLISH' ) PUBLISH,
'INCREMENTAL      : ' || dbms_stats.get_prefs('INCREMENTAL' ) INCREMENTAL,
'STALE_PERCENT    : ' || dbms_stats.get_prefs('STALE_PERCENT' ) STALE_PERCENT,
'CONCURRENT       : ' || dbms_stats.get_prefs('CONCURRENT' ) STALE_PERCENT
from DUAL
/

EOF
exit
# ......................................................................
# List table statistics locked
# ......................................................................
elif [ "$CHOICE" = "LIST_LOCK"  ]; then
    if [ -n "$fowner" ];then
        AND_OWNER=" and owner='$fowner' "
    else
        unset AND_OWNER
    fi
    sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed on pause off verify on
col owner for a30
col TABLE_NAME for a30
col PARTITION_name for a30
select 
       owner, TABLE_NAME , partition_name, 
       to_char(last_analyzed,'YYYY-MM-DD HH24:MI:SS') last_analyzed, stale_stats
    from dba_tab_statistics where STATTYPE_LOCKED is not null  $AND_OWNER
    order by owner, table_name 
/
EOF

# ......................................................................
# Set table ( partition ) stats
# ......................................................................
elif [ "$CHOICE" = "SET_TBL_STAT"  ]; then
 #-numrows ) SET_NUMROWS=$2 ; shift ;;
 #-numblks ) SET_NUMBLKS=$2 ; shift ;;
# -avgrlen ) SET_AVGRLEN=$2 ; shift ;;
echo "l_part=$l_part"
  if [ -n "$SET_NUMROWS" ];then
       F_NUMROWS=" , numrows => $SET_NUMROWS"
  fi
  if [ -n "$SET_NUMBLKS" ];then
       F_NUMBLKS=" , numblks=> $SET_NUMBLKS"
  fi
  if [ -n "$SET_AVGRLEN" ];then
       F_AVGRLEN=" ,  avgrlen=> $SET_AVGRLEN"
  fi
  if [ -n "$l_part" ];then
      F_PART=", partname=>'$l_part' "
  fi
SQL="
exec dbms_stats.SET_TABLE_STATS( ownname => '$fowner', tabname => '$ftable'  $F_PART $F_NUMROWS $F_NUMBLKS $F_AVGRLEN );
"
echo "$SQL"
if [ "$EXECUTE"  = "TRUE" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed on pause off verify on
$SQL
EOF
fi
exit
# ......................................................................
# Set table ( partition ) stats
# ......................................................................
elif [ "$CHOICE" = "SET_COL_STAT" ];then
echo "l_part=$l_part"
  if [ -n "$SET_DISTINCT" ];then
       F_DISTINCT=" , distcnt=> $SET_DISTINCT"
  fi
  if [ -n "$SET_DENSITY" ];then
       F_DENSITY=" , density=> $SET_DENSITY"
  fi
  if [ -n "$SET_NULLCNT" ];then
       F_NULLCNT=" , nullcnt=> $SET_NULLCNT"
  fi
  if [ -n "$l_part" ];then
      F_PART=", partname=>'$l_part' "
  fi
  if [ -n "$COL_LIST" ];then
      F_COL_LIST=" , colname => '$COL_LIST'"
  fi
SQL="
exec dbms_stats.SET_COLUMN_STATS( ownname => '$fowner', tabname => '$ftable' $F_COL_LIST $F_PART $F_DISTINCT $F_NULLCNT $F_DENSITY );
"
echo "$SQL"
if [ "$EXECUTE"  = "TRUE" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed on pause off verify on
$SQL
EOF
fi
exit
# ......................................................................
# Set columns stats (mainly density)
# ......................................................................
#  -numrows <nn>  -numblks <nn> -avgrlen <nn>
elif [ "$CHOICE" = "SET_STATS" ];then

  if [ -n "$SET_DISTINCT" ];then
       DISTINCT=" , distcnt=> $SET_DISTINCT"
  fi
  if [ -n "$SET_DENSITY" ];then
       DENSITY=" , density=> $SET_DENSITY"
  fi
  if [ -n "$SET_NULLCNT" ];then
       nullcnt=" , distcnt=> $SET_NULLCNT"
  fi
SQL="
exec dbms_stats.set_column_stats( ownname => '$fowner', tabname => '$ftable', colname => '$COL_LIST' $DISTINCT $NULLCNT $DENSITY );
"
echo "$SQL"
if [ "$EXECUTE"  = "TRUE" ];then
    sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed on pause off verify on
$SQL
EOF
fi
exit
# ......................................................................
# Show the stats as they are in the system for a given table/column
# ......................................................................
elif [ "$CHOICE" = "GET_STATS" ];then
COL_LIST=`echo $COL_LIST | tr -d '\n'`
SQL="
set serveroutput on
DECLARE
l_distcnt     NUMBER       DEFAULT NULL;
l_density     NUMBER       DEFAULT NULL;
l_nullcnt     NUMBER       DEFAULT NULL;
l_srec        DBMS_STATS.STATREC;
l_avgclen     NUMBER       DEFAULT NULL;

BEGIN

DBMS_STATS.GET_COLUMN_STATS (
           ownname=> '$fowner',
           tabname=> '$ftable',
           partname=> '$l_part',
           colname=> '$COL_LIST',
           distcnt=> l_distcnt,
           density=> l_density,
           nullcnt=> l_nullcnt,
           srec   => l_srec,
           avgclen=> l_avgclen);
dbms_output.put_line( 'Table       : ' || '$fowner'||'.'||'$ftable' ||chr(10)
                    ||'Column name : ' || '$COL_LIST'  || chr(10)
                    ||'distinct    : ' || to_char(l_distcnt)  || chr(10)
                    ||'density     : ' || to_char(l_density)   || chr(10)
                    ||'null count  : ' || to_char(l_nullcnt)   ||chr(10)
                    ||'avg len     : ' || to_char(l_avgclen) );
end;
/
"
sqlplus -s "$CONNECT_STRING" <<EOF
set trimspool on lines 190 pages 66 feed off pause off verify off
$SQL
EOF
exit
# ................................................
# List existing stats tables in DB or per scheman
# ................................................
elif [ "$CHOICE" = "LIST_NOT_ANALYZED_TBL" ];then
    # based on an idea of Martin Wildlake : http://mwidlake.wordpress.com/2009/07/23/automated-statistics-gathering-silently-fails-2
    # This query does not tale in account partitions and subpartitions
    if [ -n "$fowner" ];then
        AND_OWNER=" and dbta.owner='$fowner' "
    else
        unset AND_OWNER
    fi
    if [ -n "$ftable" ];then
        AND_TABLE=" and dbta.table_name='$ftable' "
    else
        unset AND_TABLE
    fi
    NDAYS=${NDAYS:-1}
     sqlplus -s "$CONNECT_STRING"<<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)||' Tables not analyzed that should be' 
from sys.dual ;
set lines 160 head on
colu anlyzd_rows form 99999,999,999  
colu tot_rows form 99999,999,999  
colu tab_name form a45  
colu chngs form 99,999,999,999  
colu pct_c form 9999999990.99
col truncated head 'Trun|cated' for a5 justify l
select dbta.owner||'.'||dbta.table_name tab_name
     , dbta.num_rows anlyzd_rows
     , to_char(dbta.last_analyzed,'yyyy-mm-dd hh24:mi:ss') last_anlzd
     , nvl(dbta.num_rows,0)+nvl(dtm.inserts,0) -nvl(dtm.deletes,0) tot_rows
     , nvl(dtm.inserts,0)+nvl(dtm.deletes,0)+nvl(dtm.updates,0) chngs
     ,(nvl(dtm.inserts,0)+nvl(dtm.deletes,0)+nvl(dtm.updates,0)) /greatest(nvl(dbta.num_rows,0),1)  pct_c
     , dtm.truncated
   from dba_tab_statistics dbta
        left outer join sys.dba_tab_modifications dtm
                        on dbta.owner = dtm.table_owner
                       and dbta.table_name = dtm.table_name
                       and dtm.partition_name is null
    where 1=1 $AND_OWNER $AND_TABLE
      and dbta.last_analyzed < sysdate - $NDAYS
      --and nvl(dtm.inserts,0)+nvl(dtm.deletes,0)+nvl(dtm.updates,0) > 0 
      and STALE_STATS = 'YES'
      AND dtm.table_name not like 'BIN$%'
      AND dbta.table_name not like 'BIN$%'
 order by dbta.last_analyzed desc;
EOF
exit
# ................................................
# list stale statistics
# ................................................
elif [ "$CHOICE" = "LIST_STALE" ];then
     if [ -n "$fowner" ] ;then
        fowner=`echo $fowner | tr '[a-z]' '[A-Z]'`
        AND_FOWNER=" and OWNER = '$fowner' "
     fi
     sqlplus -s "$CONNECT_STRING"<<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)||' Tables with stale statistics' 
from sys.dual ;
set head on pages 900 lines 157
col owner format a30
col table_name format a30
col stale_stats head Stale for a5
select owner,table_name, stale_stats, to_char(last_analyzed,'YYYY-MM-DD HH24:MI:SS')last_analyzed
 from dba_tab_statistics
 where owner not like ('SYS%')  $AND_FOWNER
   and owner not in ( 'WMSYS','DBSNMP','OUTLN','XDB','ORDSYS','MDSYS','EXFSYS') 
   and table_name not like 'BIN$%'
   and stale_stats = 'YES'
 order by last_analyzed desc
/
EOF
exit
# ................................................
# List existing stats tables in DB or per scheman
# ................................................
elif [ "$CHOICE" = "LIST_LAST_RUN" ];then
     sqlplus -s "$CONNECT_STRING"<<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||rpad(USER,15)||' last execution of DBMS_GATHER_STATS' 
from sys.dual ;
col operation for a30
col target for a62 head 'Target'
col start_time for a26
col end_time for a26
set head on lines 190
col job_name for a25
col cpu_used for a20
col run_duration for a20
col additional_info for a41
col status for a16
col error# for 9999999
select job_name, to_char(actual_START_DATE,'YYYY-MM-DD HH24:MI:SS') req_start_date
,CPU_USED,RUN_DURATION,STATUS,error#, additional_info
from DBA_SCHEDULER_JOB_RUN_DETAILS 
 where job_name = 'GATHER_STATS_JOB' order by 2 desc
/
prompt Additional gather statistics run
prompt
 select operation, target,
       to_char(start_time,'YYYY-MM-DD HH24:MI:SS.FF4') start_time,
       to_char(  end_time,'YYYY-MM-DD HH24:MI:SS.FF4') end_time
 from dba_optstat_operations where operation != 'gather_database_stats(auto)'
 order by start_time desc ;
EOF
exit
# ................................................
# List existing stats tables in DB or per scheman
# ................................................
elif [ "$CHOICE" = "LIST_PARAM" ];then
     sqlplus -s "$CONNECT_STRING"<<EOF
     set pagesize 0 feed on head on pause off
col parameter format a20
col value format a40
set head on
select 'method_opt' parameter, dbms_stats.get_param('method_opt')  value from dual
union
select 'cascade' parameter, dbms_stats.get_param('cascade') value from dual
union
select 'estimate_percent' parameter, dbms_stats.get_param('estimate_percent') value from dual
union
select 'degree' parameter ,dbms_stats.get_param('degree') value from dual
union
select 'no_invalidate' parameter ,dbms_stats.get_param('no_invalidate') value from dual
union
select 'granularity' parameter ,dbms_stats.get_param('granularity') value from dual
union
select 'autostats_target' parameter ,dbms_stats.get_param('autostats_target')value from dual ;
EOF
exit
# ................................................
# Gather/delete system statistics
# ................................................
elif [ "$CHOICE" = "GSYS" ];then
    if [ "$GET" = "TRUE" ];then
            VAR0=${MODE:-noworkload}
            VAR="gathering_mode=>'$VAR0'"
            if  [ -n "$INT_MINUTES" ];then
                 VAR="gathering_mode=>'INTERVAL', interval=> $INT_MINUTES"
            fi
            SQL="Prompt doing exec dbms_stats.gather_system_stats($VAR);
            exec dbms_stats.gather_system_stats($VAR);"
    else
            SQL="Prompt doing exec dbms_stats.delete_system_stats();
exec dbms_stats.delete_system_stats();"
      fi
    echo "$SQL"
    if [ "$EXECUTE" = TRUE ];then
sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
EOF
    fi
    exit
# ................................................
# Gather/delete stats tables on SYS tables
# ................................................
elif [ "$CHOICE" = "GFIX" ];then
      if [ "$GET" = "TRUE" ];then
            SQL="Prompt doing exec dbms_stats.gather_fixed_objects_stats(NULL);
exec dbms_stats.gather_fixed_objects_stats();
prompt List stat from table owned by SYS:
select distinct nvl(to_char(trunc(last_analyzed)),'No stats')Date_taken, count(*)
from dba_tables where owner='SYS' group by trunc(last_analyzed) order by 1 desc;
"
      else
            SQL="Prompt doing exec dbms_stats.delete_fixed_objects_stats();
exec dbms_stats.delete_fixed_objects_stats();
prompt List stat from table owned by SYS:
select distinct nvl(to_char(trunc(last_analyzed)),'No stats')Date_taken, count(*)
from dba_tables where owner='SYS' group by trunc(last_analyzed) order by 1 desc; "
      fi
    if [ "$EXECUTE" = TRUE ];then
sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
EOF
    else
      echo "$SQL"
    fi
    exit
fi

# if owner is not given, deduce it as if the table is unique in DB otherwise output err and exit
if [ -z "$fowner" -a ! "$LIST_STAT" = "TRUE" ];then
   # we use one sql for index and table
   if [ -n "$ftable" ];then
   fvar=`sqlplus -s "$CONNECT_STRING"<<EOF
        set pagesize 0 feed off head off pause off
        select  owner from dba_tables where table_name = '$ftable';
EOF`
  elif [ -n "$findex" ];then
   fvar=`sqlplus -s "$CONNECT_STRING"<<EOF
        set pagesize 0 feed off head off pause off
        select  owner from dba_indexes where index_name = '$findex';
EOF`
   fi
   if [ -z "$fvar" ];then
      echo "could not determine the owner of the object, please use -u <OWNER>"
      exit
   fi
   nbr=`echo $fvar | wc -w`
   if [ ! $nbr -eq 1 ];then
        echo "Mutilple user (\"`echo $var | tr '\n' ' '`\") or non existent table ==> abort"
        echo "user -u <owner>"
        exit
   else
        fowner=`echo $fvar | awk '{print $1}'`
        if [ -z $fowner ];then
            echo "Owner is blank"
            exit 1
        fi
   fi
fi
if [ -z "$l_fstatid" ];then
   var=`echo $ftable | cut -c1-12`
   fstatid=$var$fdate
else
   fstatid=$l_fstatid
   AND_STATID=" and statid='$l_fstatid' "
fi
fstattab=${l_fstattab:-sm_stattab}
fstat_owner=${fstat_owner:-$fowner}
fpart=${l_part:-NULL}
FOUT=$SBIN/tmp/gather_tbl_stats_${ftable}_${fowner}.log
FIL_EXECUTE=$SBIN/tmp/sta_$fstab_$fowner.sql
if [ "$EXECUTE" = "TRUE" ];then
    > $FIL_EXECUTE
fi
$SETXV
# ....................................
# Create the stattab table is required
# ....................................
if [ "$CREATE_STATTAB" = "TRUE" ];then
     sqlplus -s "$CONNECT_STRING"<<EOF
     set pagesize 0 feed on head on pause off
     prompt Doing: dbms_stats.create_stat_table( '$fowner','$fstattab' $TBS) ;
     execute dbms_stats.create_stat_table( '$fowner','$fstattab' $TBS) ;
EOF
    exit
fi

# ................................................
# List existing stats tables in DB or per scheman
# ................................................
if [ "$LIST_STAT" = "TRUE" ];then
     if [ -n "$fowner" ];then
         FOWNER=" and a.owner='$fowner'"
     fi
     if [ -z "$l_fstattab" ];then
        sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'List of table stats: for owner ${fowner:-ALL}' nline
from sys.dual
/
          set linesize 124 pagesize 64 feed on head on pause off
          select a.owner,a.table_name
               from all_tab_columns a, all_tab_columns b , all_tab_columns c
           where
               a.owner = b.owner and a.owner = c.owner and a.table_name = b.table_name and
               a.table_name = c.table_name and a.column_name='STATID'  and b.column_name='CH1' and
               c.column_name='FLAGS' $FOWNER
/
EOF
    else
        sqlplus -s "$CONNECT_STRING" <<EOF
ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 100 termout on pause off embedded on verify off heading off
spool $FOUT

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Number of type of stats available in $fstattab per object' nline
from sys.dual
/
          set linesize 124
          set pagesize 64 feed on head on pause off
          col owner format A20
          col statid format A20
          col sub  format 999999 head ' Sub |Partition' justify c
          col part format 999999 head 'Partition'
          col col format 999999 head 'Columns'
          col global format 9999 head 'Glob'
          break on owner on  statid
          prompt .         T=table         I=Index
          prompt
          select a.c5 owner, a.statid,  a.c1 object, a.type ,
                 (select count(rownum) from $fowner.$fstattab where
                           nvl(statid,1)=nvl(a.statid,1) and c5=a.c5 and c1=a.c1 and c2 is null and c3 is null and c4 is null ) Global ,
                 (select count(rownum) from $fowner.$fstattab where
                           statid=a.statid and c5=a.c5 and c1=a.c1 and c2 is not null and c3 is null
                           and c4 is null ) part,
                 (select count(rownum) from $fowner.$fstattab where
                           statid=a.statid and c5=a.c5 and c1=a.c1 and c2 is not null and c3 is not null
                           and c4 is null) Sub ,
                 (select count(rownum) from $fowner.$fstattab where
                           statid=a.statid and c5=a.c5 and c1=a.c1 and c2 is not null and c3 is not null
                           and c4 is not null) col
          from  $fowner.$fstattab a where C4 is null $AND_STATID
               group by a.c5, a.statid, a.c1, a.type
               order by statid,a.type desc
/
EOF
    fi
    exit
fi

if [  "$COPY_ST_STTAB" = "TRUE" ];then
    COPY_ST_STTAB=" ,stattab=>'$fstattab', statid=>'$fstatid', statown=>'$fstat_owner'"
else
   unset COPY_ST_STTAB
fi
# ....................................
#   Delete STATS
# ....................................
if [ "$fdel" = "TRUE" ];then
     # we don't want a default created statid if not statid is requested
     if [ -n "$l_fstattab" ];then
           ST_STATTAB=",stattab=>'$l_fstattab'"
     fi
     if [ -n "$l_fstatid" ];then
        ST_STATID=",statid=>'$l_fstatid'"
     fi
     if [ "$fcasc" = "TRUE" ];then
        DEL_CASC_IDX=",cascade_indexes => TRUE "
     fi
     if [ "$STAT_SYSTEM" = "TRUE" ];then
        PROC=system
        unset DEL_CASC_IDX
        unset DEL_CASC_COL
        unset DEL_CASC_PART
     elif [ -n "$ftable" ];then
        if [ -n "$COL_LIST" ];then
           PROC=column
           DEL_COL=",colname=> '$COL_LIST'"
        else
           PROC=table
        fi
        ST_OWNER=",ownname=>'$fowner'"
        ST_OBJ=",tabname=>'$ftable'"
     elif [ -n "$findex" ];then
        PROC=index
        ST_OBJ=",indname=>'$findex'"
        ST_OWNER=",ownname=>'$fowner'"
        unset DEL_CASC_IDX
        unset DEL_CASC_COL
     elif [ -n "$user" ];then
       PROC=schema
        unset DEL_CASC_IDX
        unset DEL_CASC_COL
        unset DEL_CASC_PART
     fi
     SQL="exec dbms_stats.delete_${PROC}_stats ( statown=>'$fstat_owner' $ST_STATTAB $ST_OWNER $ST_OBJ $DEL_COL $DEL_CASC_COL $DEL_CASC_IDX $DEL_CASC_PART $ST_STATID ) ; "
     echo $SQL
     if [ "$EXECUTE" = "TRUE" ];then
        echo $SQL >> $FIL_EXECUTE
        do_execute
     fi
     exit
fi
#pol
if [ -n "$OPTIONS" ];then
  OPTIONS=" ,options=> 'GATHER AUTO' "
fi
# ....................................
#    Export/import STATS
# ....................................
if [ "$EXPORT_STAT" = "TRUE" -o "$IMPORT_STAT" = "TRUE" ];then
   if [ "$EXPORT_STAT" = "TRUE" ];then
      IMXP=export
   else
      IMXP=import
   fi
   if [ "$fpart" = "NULL" ];then
      ST_PART=",partname=>NULL"
   else
      ST_PART=",partname=>'$fpart'"
   fi
   if [ "$STAT_SYSTEM" = "TRUE" ];then
      PROC=${IMXP}_system_stats            # import_system_stats or export_system_stats
   elif [ -n "$ftable" ];then
      G_FTABLE="tabname=> '$ftable' ,"
      G_CASCADE="cascade=> $fcasc ,"
      G_OWNER="ownname=>'$fowner' ,"
      PROC=${IMXP}_table_stats
     
      SQL="exec dbms_stats.${IMXP}_table_stats( ownname=>'$fowner', tabname=> '$ftable' $ST_PART, cascade=> $fcasc  $METHOD_OPT $COPY_ST_STTAB $OPTIONS) "
      echo "Doing $SQL"
      sqlplus -s "$CONNECT_STRING"<<EOF
           $SQL
EOF
      cpt=`get_tab_nbr_part`
      if [ $cpt -gt -1 -a -z "$l_part" ];then
         PART_NAME=`ret_part PART_NAME $cpt TAB`
         DBA_TAB=`ret_part DBA_TAB $cpt TAB`
         LST_PART=`sqlplus -s "$CONNECT_STRING" >| tr -d '\d' <<EOF
         set pagesize 0 feed off head off pause off
         select $PART_NAME from $DBA_TAB where table_owner = '$fowner' and table_name = '$ftable' order by 1;
EOF`
         typeset -u fpart
a=1
#bpa1
         for fpart in `echo "$LST_PART"`
         do
           SQL="exec dbms_stats.${IMXP}_table_stats( ownname=>'$fowner', tabname=> '$ftable', partname=> '$fpart', cascade=> $fcasc $OPTIONS $METHOD_OPT $COPY_ST_STTAB) "
           echo "Doing $SQL"
           sqlplus -s "$CONNECT_STRING"<<EOF
alter session set events '10046 trace name context forever,level 12' ;
           $SQL
EOF
           unset SQL
         done
      fi

   elif [ -n "$findex" ];then
      G_OWNER="ownname=>'$fowner' ,"
      G_FTABLE=", indname=> '$ftable' ,"
      unset G_CASCADE
      PROC=${IMXP}_index_stats
      SQL="exec dbms_stats.${IMXP}_index_stats( ownname=>'$fowner', indname=> '$findex' $ST_PART $COPY_ST_STTAB) "
      echo "Doing $SQL"
      sqlplus -s "$CONNECT_STRING"<<EOF
           $SQL
EOF
      cpt=`get_ind_nbr_part`
      if [ "$cpt" -gt -1 -a -z "$l_part" ];then
         PART_NAME=`ret_part PART_NAME $cpt IND`
         DBA_TAB=`ret_part DBA_TAB $cpt IND`
         LST_PART=`sqlplus -s "$CONNECT_STRING"<<EOF
         set pagesize 0 feed off head off pause off
         select $PART_NAME from $DBA_TAB where index_owner = '$fowner' and index_name = '$findex' order by 1;
EOF`
         typeset -u fpart
         for fpart in `echo $LST_PART`
         do
           SQL="exec dbms_stats.${IMXP}_index_stats( ownname=>'$fowner', indname=> '$findex', partname=> '$fpart' $COPY_ST_STTAB) "
           echo "Doing $SQL"
           sqlplus -s "$CONNECT_STRING"<<EOF
           $SQL
EOF
           unset SQL
         done
      fi
   elif [ -n "$fowner" ];then
      G_OWNER="ownname=>'$fowner' ,"
      PROC=${IMXP}_schema_stats
      SQL="exec dbms_stats.$PROC( $G_OWNER $G_FTABLE $G_CASCADE $COPY_ST_STTAB) "


      echo "Doing $SQL"
      sqlplus -s "$CONNECT_STRING" <<EOF
      $SQL
EOF
   else
      echo "Error in input selection ==> abort"
   fi

  exit
fi
# ********************************************************
# ********************************************************
#  Gather stats for TABLE,INDEX or SCHEMA
# ********************************************************
#
# ********************************************************
# A) Gather stats for TABLE
# ********************************************************
if [ -n "$ftable" ];then
  # ....................................
  # check if we will gather stats only
  # for some columns
  # ....................................
A=1
  if [ -n "$COL_LIST" ];then
     if [ -n "$CSIZE" ];then
        COL_SIZE=" size $CSIZE"
     fi
     if [ -n "$SKEW" ];then
        COL_SIZE=" size SKEWONLY"
     fi
     METHOD_OPT=", method_opt => 'For columns ${COL_LIST} $COL_SIZE'"
  elif  [ -n "$METHOD_OPT" ];then
     METHOD_OPT="$METHOD_OPT"
  fi
  # ....................................
  # check if table is not partitioned :
  # ....................................
  var=`sqlplus -s "$CONNECT_STRING" <<EOF
     set pagesize 0 feed off head off pause off
     select  partitioned from dba_tables where owner = '$fowner' and table_name = '$ftable';
EOF`
  var=`echo $var |tr -d '\r'`

  # ....................................
  # Partition or sub partition?
  # ....................................
  if [ "$var" = "YES" -a ! "$fgran" = "GLOBAL" -a ! "$fgran" = "ALL" -a ! "$fgran" = "DEFAULT" -a -z "$l_part" ];then
     part_cpt=`get_tab_nbr_part`
     PART_NAME=`ret_part PART_NAME $part_cpt TAB`
     DBA_TAB=`ret_part DBA_TAB $part_cpt TAB`
     # .............................................
     # loop on partitions now to issue the statement
     # .............................................
     LST_PART=`sqlplus -s "$CONNECT_STRING"<<EOF
       set pagesize 0 feed off head off pause off
       select $PART_NAME from $DBA_TAB where table_owner = '$fowner' and table_name = '$ftable' order by 1;
EOF`
     typeset -u fpart

     for fpart in `echo ${LST_PART}`
     do
          SQL="exec dbms_stats.gather_table_stats( ownname=>'$fowner'," 
          SQL="$SQL tabname=> '$ftable', partname=> '$fpart', degree=> $fdegree, estimate_percent=> $fperc,"
          SQL="$SQL granularity=>'$fgran', cascade=>$fcasc $COPY_ST_STTAB $OPTIONS $METHOD_OPT $OPTIONS ) "
        echo "$SQL" | tr -d '\r'
        if [ "$EXECUTE" = "TRUE" ];then
           echo "$SQL" | tr -d '\r' >> $FIL_EXECUTE
        fi
     done

  else
     # .............................................
     # No partitions or single (sub)pationtion
     # .............................................
     if [ -n "$l_part" ];then
         ST_PARTNAME="partname=> '$l_part',"
     fi
     SQL="exec dbms_stats.gather_table_stats( ownname=>'$fowner', tabname=> '$ftable', Degree=> $fdegree,  $ST_PARTNAME"
     SQL="$SQL estimate_percent=> $fperc, granularity=>'$fgran', cascade=>$fcasc $COPY_ST_STTAB $OPTIONS $METHOD_OPT) "
     echo "$SQL" | tr -d '\r'
     if [ "$EXECUTE" = "TRUE" ];then
          echo "$SQL"  | tr -d '\r'>> $FIL_EXECUTE
     fi
   fi

  # ********************************************************
  # B) INDEX
  # ********************************************************

  elif [ -n "$findex" ];then # index
  # ....................................
  # check if Index is not partitioned :
  # ....................................
  var=`sqlplus -s "$CONNECT_STRING"<<EOF
     set pagesize 0 feed off head off pause off
     select  partitioned from dba_indexes where owner = '$fowner' and index_name = '$findex';
EOF`

  # ....................................
  # Partition of sub partition?
  # ....................................
  if [ "$var" = "YES" -a ! "$fgran" = "GLOBAL" -a !  "$fgran" = "ALL" -a ! "$fgran" = "DEFAULT" -a -z "$l_part" ];then
     cpt=`get_ind_nbr_part`

     # you can have subpartitions but not necessarily ask sta on subpartitions. so we test on fgran
     # and no specific partition were mentioned
     if [ $cpt -gt -1  -a -z "$l_part" -a "$fgran" = "SUBPARTITION" ];then
        PART_NAME=`ret_part PART_NAME $cpt IND`
        DBA_TAB=`ret_part DBA_TAB $cpt IND`
        if [ "$fgran" = "ALL" -o "$fgran" = "SUBPARTITION" ];then
           :
        else
           echo "Garther stats for subpartitions are only done for Granularity = \"ALL\" or \"SUBPARTITION\""
           echo "If you are not happy with that, you can send your instults at ceo@Oracle.com"
           echo "Aborting ==>"
           exit 0
        fi
     else
        PART_NAME=PARTITION_NAME
        DBA_TAB=DBA_IND_PARTITIONS
     fi
     # .............................................
     # loop on partitions now to issue the statement
     # .............................................
     LST_PART=`sqlplus -s "$CONNECT_STRING"<<EOF
     set pagesize 0 feed off head off pause off
     select $PART_NAME from $DBA_TAB where index_owner = '$fowner' and index_name = '$findex' order by 1;
EOF`
     typeset -u fpart
     for fpart in `echo $LST_PART`
     do
       SQL="exec dbms_stats.gather_index_stats( ownname=>'$fowner',
                    indname=> '$findex',
                    partname=> '$fpart',
                    estimate_percent=> $fperc $COPY_ST_STTAB) "
        echo $SQL
        if [ "$EXECUTE" = "TRUE" ];then
            echo $SQL >> $FIL_EXECUTE
        fi
     done

  else

     # .............................................
     # No partitions
     # .............................................
     if [ -n "$l_part" ];then
         ST_PARTNAME="partname=> '$l_part',"
     fi
     SQL="exec dbms_stats.gather_index_stats( ownname=>'$fowner',
                         indname=> '$findex', $ST_PARTNAME
                         Degree=> $fdegree,
                         estimate_percent=> $fperc $COPY_ST_STTAB) "
   echo $SQL
    if [ "$EXECUTE" = "TRUE" ];then
       echo $SQL >> $FIL_EXECUTE
    fi
 fi
else
     SQL="exec dbms_stats.gather_schema_stats( ownname=>'$fowner',
                         Degree=> $fdegree,
                         estimate_percent=> $fperc $COPY_ST_STTAB) "
     echo $SQL
     if [ "$EXECUTE" = "TRUE" ];then
       echo $SQL >> $FIL_EXECUTE
    fi

fi



  if [ "$EXECUTE" = "TRUE" ];then
     do_execute
  fi

