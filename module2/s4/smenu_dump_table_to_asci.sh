#!/usr/bin/ksh
#set -xv
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=${SBIN}/scripts
WK_SBIN=${SBIN}/module2/s4
TMP=$SBIN/tmp
#FOUT=$TMP/dump_$ORACLE_SID.txt
echo "OWNER of the table ==> \c"
read F_USER
echo "Name of the table ==> \c"
read FTABLE

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get the password of $S_USER"
   exit 0
fi
cd $SBIN/tmp
cp $WK_SBIN/smenu_dump_table_to_asci.sql $SBIN/tmp/unload_tbl$$.sql
sqlplus -s "$CONNECT_STRING" @unload_tbl$$ $F_USER $FTABLE 
rm $SBIN/tmp/unload_tbl$$.sql  f_dump.sql f_dtmp.sql
ftable=`echo $FTABLE |  tr 'A-Z' 'a-z'`
if $SBINS/yesno.sh "That I create a tar file with the data,ctl and par file"  DO Y
   then
     gzip $ftable.txt 
     tar cvf ${ftable}_gz.tar ./$ftable.txt.gz ./$ftable.par ./$ftable.ctl
     rm  ./$ftable.txt.gz ./$ftable.par ./$ftable.ctl
fi
