#!/bin/sh
# set -xv
# B. Polarski
# 25 November 2005
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
# -----------------------------------------------------------------------------
function help {
cat <<EOF

       ttbi -d <IMP_DIR> -f <IMP_FILE>


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
# -----------------------------------------------------------------------------
while [ -n "$1" ]
do
    case "$1" in
      -d ) DIR_IMP=$2
           shift ;;
      -f ) IMP_FILE=$2
           shift ;;
      -h ) help ;;
      -l ) LIST=TRUE;;
       * ) break ;;
    esac
    shift
done
DIR_IMP=${DIR_IMP:-$SBIN/tmp}
cd $DIR_IMP
if [ -z "$FIL_DMP" ];then
   FIL_DMP=`ls -t $DIR_IMP/ttbs_*.dmp | head -1`
fi
if [ "$LIST" = "TRUE" ];then
   cd $DIR_IMP
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
