#!/bin/sh
# set -xv
# B. Polarski
# 25 November 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
FNAME=ttbs_`date +%m%d%H%M`.dmp
while [ -n "$1" ]
do
  case $1 in
    -d ) EXP_DIR=$2 
         shift ;;
    -f ) FIL_DMP=$2
         shift ;;
  esac
  shift
done
EXP_DIR=${EXP_DIR:-$SBIN/tmp}
FIL_DMP=${FIL_DMP:-$FNAME}
FIL_INI=`echo $FIL_DMP | sed 's/\.dmp//'`.dat
FOUT=$EXP_DIR/$FIL_INI
FEXP=$EXP_DIR/$FIL_DMP
# --------------------------------------------------------------------------
function do_export
{

VAR="$1"
VAR1=`echo $VAR |sed 's@\([^ ][^ ]*\) @\1#,#@g' | tr '#' "'"`
TBS="'${VAR1}'"

sqlplus -s "$CONNECT_STRING" >/dev/null <<EOF
set pause off head off pagesize 0 linesize 124
spool $FOUT
set linesize 120
select 'file:'||file_name||':tbs:'||tablespace_name||':' tbs from dba_data_files where tablespace_name in ($TBS)
/
select distinct 'owner:'||owner||':' from dba_data_files d,dba_segments s 
       where d.tablespace_name in ($TBS) and d.tablespace_name = s.tablespace_name
/
spool off
/
EOF
PAR1="`echo $VAR | tr ' ' ','`"
echo "MACHINE $HOST - ORACLE_SID : $ORACLE_SID           Page:  1 "

exp "'/ as sysdba'" file=${FEXP} TRANSPORT_TABLESPACE=y TABLESPACES="(${PAR1})"

}
# --------------------------------------------------------------------------

CONNECT_STRING='/ as sysdba'
LIST_TBL=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pagesize 0
select tablespace_name from DBA_TABLESPACES
/
EOF
`
echo " "
PS3=' Select list of tablespace to Transport, "e" to abort, "t" to start process  ===> '
echo " "
echo " Tablespace to export:\n\n"
TO_EXPORT=
select TABLESPACE in ${LIST_TBL}
   do
      if [ "${REPLY}" = 'e' ]; then
          exit
      elif [ "${REPLY}" = 't' ]; then
         echo
         echo
         if $SBINS/yesno.sh "To export $TO_EXPORT" DO
         then
            do_export "$TO_EXPORT"
            echo "Metadata Export is : $FEXP"
            echo "List of datafiles  : $FOUT"
            break
         fi
      elif [ -n "${TABLESPACE}" ]; then
         TO_EXPORT="$TO_EXPORT  $TABLESPACE"
      else
         print -u2 "Invalid choice"
      fi
      echo "List --> $TO_EXPORT"
done
