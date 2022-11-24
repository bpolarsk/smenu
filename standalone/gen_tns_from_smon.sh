#oracle   2754560       1  0 Sep27 ?        00:00:05 ora_smon_WAAPOC1E12
LHOST=`hostname`
> $SBIN/data/tnsnames.smon
 ps -ef | grep ora_smon_ | grep -v grep | while read ni ni ni ni ni ni ni smon
do
  fsid=`echo $smon | sed 's/.*_smon_//'`
echo "${fsid}=" >> $SBIN/data/tnsnames.smon
echo "   (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$LHOST)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SID=$fsid)))" >> $SBIN/data/tnsnames.smon
done
