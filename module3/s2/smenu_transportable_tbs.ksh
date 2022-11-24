#!/bin/sh
# Programm        : smenu_check_ttbl.ksh
# Author          : B. Polarski
# date            : 23 May 2005
# Modification    : 27 November 2005

# set -xv

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
function do_check
{
VAR="$1"
TBS=`echo $VAR |sed 's@\([^ ][^ ]*\) @\1,@g' `

echo "Checking for $TBS"
sqlplus -s "$CONNECT_STRING" <<EOF
execute dbms_tts.transport_Set_check(TS_LIST=>'$TBS',incl_constraints=>TRUE)
prompt Counting from transport_set_violations;

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 170
set termout on pause off
set embedded on
set verify off
set heading off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline,
       'Display Violation to transport tablespace $TBS' nline
from sys.dual
/

set head on

COL Violations                FORMAT A170      HEADING 'Violations'

SELECT violations
  FROM transport_set_violations ;

EOF

}

# ------------------------------------------------------------------------------------
function help
{
 more <<EOF

   Transportable tablespace;

     ttb  -c                               # Perform a check for a tablespace (a list of suitable tbs is displayed)
     ttb  -e  -d<dir> -f <file_dmp>        # Perform an exporte tablespace
     ttb  -i                               # import the tablespace (run ttb -e first)

 Expample:

       ttb -i -d <IMP_DIR> -f <IMP_FILE>


      notes : IMP_DIR is the directory containing the *.dat and *.dmp
              IMP_FILE is the dmp containings the metatdata of the import.

The metat data file has the following structure :
..................................................
file:/u02/oradata/CUST/read_only2_01.dbf:tbs:READ_ONLY2:
file:/u02/oradata/CUST/read_only01.dbf:tbs:READ_ONLY:
owner:STAT
owner:SYSTEM


EOF
exit
}
# ------------------------------------------------------------------------------------

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
FNAME=ttbs_`date +%m%d%H%M`.dmp
WRK_DIR=${WRK_DIR:-$SBIN/tmp}
FIL_DMP=${FIL_DMP:-$FNAME}
FIL_INI=`echo $FIL_DMP | sed 's/\.dmp//'`.dat
FOUT=$WRK_DIR/$FIL_INI
FEXP=$WRK_DIR/$FIL_DMP


if [ -z "$1" ];then
     help
fi
while [ -n "$1" ]; do
   case "$1" in
      -c ) ACTION=CHECK ;;
      -e ) ACTION=EXP ;;
      -i ) ACTION=IMP ;;
      -d ) WRK_DIR=$2 ; shift ;;
      -f ) FIL_DMP=$2 ; shift ;;
      -l ) LIST=TRUE;;
      -h ) help ;;
       * ) echo "Invalid parameter" ; exit ;;

   esac
   shift
done

S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   CONNECT_STRING='/ as sysdba'
fi


# --------------------------------------------------------------------------
# Check if tablespace can be transported
# --------------------------------------------------------------------------
if [ "$ACTION" = "CHECK" ];then
      LIST_TBL=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pagesize 0
select tablespace_name from DBA_TABLESPACES
/
EOF
`
     PS3=' Select tablespace to Check, "e" to abort, "c" to start process checking  ===> '
     echo "Select tablespace to Check, "e" to abort, "c" to start process checking  ===> "
     export PS3
     echo " "
     echo " Tablespace to Check:"
     TO_CHECK=
     select TABLESPACE in ${LIST_TBL}
     do
        if [ "${REPLY}" = 'e' ]; then
            exit
        elif [ "${REPLY}" = 'c' ]; then
            echo "Checking tablespace set $TO_CHECK"
            do_check "$TO_CHECK"
            break
       elif [ -n "${TABLESPACE}" ]; then
           TO_CHECK="$TO_CHECK  $TABLESPACE"
       else
         print -u2 "Invalid choice"
       fi
       echo "List --> $TO_CHECK"
     done

# --------------------------------------------------------------------------
# export tablespace to be transported
# --------------------------------------------------------------------------
elif [ "$ACTION" = "EXP" ];then
CONNECT_STRING='/ as sysdba'
LIST_TBL=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pagesize 0
select tablespace_name from DBA_TABLESPACES
/
EOF
`
echo " "
PS3=' Select list of tablespace to Transport, "e" to abort, "t" to start process  ===> '
echo ' Select list of tablespace to Transport, "e" to abort, "t" to start process  ===> '
echo " "
echo " Tablespace to export:"
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

# --------------------------------------------------------------------------
# import transported tablespace
# --------------------------------------------------------------------------
elif [ "$ACTION" = "IMP" ];then
     WRK_DIR=${WRK_DIR:-$SBIN/tmp}
     cd $WRK_DIR
     if [ -z "$FIL_DMP" ];then
       FIL_DMP=`ls -t $WRK_DIR/ttbs_*.dmp | head -1`
     fi
     if [ "$LIST" = "TRUE" ];then
       cd $WRK_DIR
       ls -lt ttbs_*.dmp | more
       exit
     fi
     FIL_INI=`echo $FIL_DMP | sed 's/\.dmp//'`.dat
     if [ ! -f $FIL_INI ];then
        echo "FATAL ERROR : did not find $FIL_INI"
        exit 1
     fi
     FINI=`basename $FIL_INI`
     FIMP=`basename $FIL_DMP`
     VAR=`cat $FINI | grep ^file | cut -f4 -d':' |tr '\n' ' '|tr '#' "'"`
     TBS=`echo $VAR | sed 's@\([^ ][^ ]*\) @\1#,#@g' | tr '#' "'"`

     VAR=`cat $FINI | grep ^file | cut -f2 -d':' | tr '\n' ' '| tr '#' "'"`
     DATA_FILES=`echo $VAR | sed 's@\([^ ][^ ]*\) @\1#,#@g' | tr '#' "'"`

     VAR=`cat $FINI | grep ^owner | cut -f2 -d':' |tr '\n' ' '`
     OWNER=`echo $VAR | sed 's@\([^ ][^ ]*\) @\1#,#@g' | tr '#' "'"`
     if $SBINS/yesno.sh "to transport into $ORACLE_SID the tablespaces $TBS" DO
     then
        echo "OWNERS=$OWNERS"
        echo "Datafiles=$DATA_FILES"
        STR="'/ as sysdba'"
        imp  "$STR TRANSPORT_TABLESPACE=Y FILE=$FIMP DATAFILES=('$DATA_FILES') TABLESPACES=('$TBS')"
     else
        echo "Another time maybe ...."
     fi
fi
