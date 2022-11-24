#!/usr/bin/ksh
set -x
MAX=10000
cpt=0
while true 
do
  cpt=`expr $cpt + 1`
  if [ $cpt -gt $MAX ];then
     break
  fi
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
  sqlplus -s strmadmin/strmadmin @ff > /dev/null 2>&1 &
wait
done

 
  
