#!/usr/bin/ksh
#set -x
# author  : B. Polarski
# program : smenu_try_latchholder.ksh
# date    : 14 September 2006
#
if [ "$1" = "-h" ];then
   cat <<EOF

        an attempt to catche the latchholder in this evanescent view.
        Can be painful for everybody. It is so specific and resource consumming
        that it is not set with the genral latches shortcut 'lat'

   Use:

         lho


EOF
exit
fi
maxcpt=${1:-30}
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
SBINS=$SBIN/scripts
#S_USER=SYS
. $SBINS/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
      echo "could no get a the password of $S_USER"
      exit 0
fi
cpt=0
while true
do

cpt=`expr $cpt + 1`
if [ $cpt -gt $maxcpt ];then
  exit
fi
sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66
set linesize 80
set termout on
set embedded on
set verify off
set heading off pause off

select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline ,
       'Show session waits events : Short grouped version' nline
from sys.dual
rem /
set head on pause off feed off
set linesize 124

set feed on head off

Prompt SID   Latch Address Latch name
prompt --- --------------- -----------

select /*+ ordered */
  t0,
  t1,
  t2,
  t3,
  t4,
  t5,
  t6,
  t7,
  t8,
  t9,
  t10,
  t11,
  t12,
  t13,
  t14,
  t15,
  t16,
  t17,
  t18,
  t19,
  t20,
  t21,
  t22,
  t23,
  t24,
  t25,
  t26,
  t27,
  t28,
  t29,
  t30,
  t31,
  t32,
  t33,
  t34,
  t35,
  t36,
  t37,
  t38,
  t39
from
  (select sid||' '|| laddr||' '||name t0 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t1 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t2 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t3 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t4 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t5 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t6 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t7 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t8 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t9 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t10 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t11 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t12 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t13 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t14 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t15 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t16 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t17 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t18 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t19 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t20 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t21 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t22 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t23 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t24 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t25 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t26 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t27 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t28 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t29 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t30 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t31 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t32 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t33 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t34 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t35 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t36 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t37 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t38 from v\$latchholder),
  (select sid||' '|| laddr||' '||name t39 from v\$latchholder)
/
prompt
prompt
EOF
done

