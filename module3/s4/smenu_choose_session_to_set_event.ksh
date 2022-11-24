#!/bin/sh
#
# **************************************************************************
# Program  : smenu_choose_session_to_set_event.sh
# Author   : B. Polarski
# date     : 31.August.2005
# Modified :       bpa : 
#                        Added the possibility to directly pick and SID
#                        without using the session menu selection.
# **************************************************************************
#
#set -xv
trap 'if [ -f $SBIN/tmp/zzgg_1.sql ];then
          rm $SBIN/tmp/zzgg_1.sql
      fi 
      exit ' 0 2 9 13 15 
#------------------------------------------------------------------------------------------------------------
help()
{

cat <<EOF

                 sstv                 # start event trace to pick session from menu, using a ps -ef
                 sstv  13             # Start event trace, provide the SID yourself
                 sstv  13n            # to  cancel event
                 sstv  15 10053       # start event 10053 
                 sstv  15 10053  12   # start event 10053  level 12

   Note : If your are running in multithread mode, a ps -ef will not show you elapsed cpu by session.
          In this case run an 'sl' ,  pick an SID and run 'sstv SID' directly.


EOF
}
#------------------------------------------------------------------------------------------------------------
SBINS=${SBIN}/scripts
cd $SBINS
FOUT=$SBIN/tmp/zzgg_1.sql
> $FOUT
cd $SBIN/tmp

if [ "x-$ORACLE_SID" = "x-" ];then
   echo "Oracle SID is not defined .. aborting "
   exit 0
fi
if [ "x-$1" = "x--h" ];then
   #-- option 1
   help
   exit
fi
EVENT=${2:-10046}
LEVEL=${3:-12}
var=`echo $1 | grep n`
if [ $? -eq 0 ];then
     OPT=FALSE
     SID=`echo $1 |sed 's/n//'`
     $SBINS/smenu_set_event_in_session.ksh $SID $EVENT 0
     exit
fi
SID=$1
if [ -n "$SID" ];then
    $SBINS/smenu_set_event_in_session.ksh $SID $EVENT $LEVEL
    exit
fi
#--------------- option 3

SBINS=${SBIN}/scripts
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
echo " Oracle Session to set event "
echo " ---------------------------"
echo " "
ps -ef | grep -v grep | grep $ORACLE_SID | grep LOCAL >> $FOUT
cpt=1
while read a
do
  echo " $cpt : $a "
  cpt=`expr $cpt + 1`
done<$FOUT
echo 
echo " ***************************************************************************************"
echo " Default event is 10046 level 12. "
echo " If you want another event/level combo you need to type sstv <nnnnn><nn>"
echo " ie : sstv <sid> 10046 4"
echo 
echo "  Type 'sstv -h' for help "
echo 
echo "    If you are running in multithreaded mode then you need to launch sstv,"
echo "    providing the SID yourself as first parameter : sstv 13 [10059] [12] "
echo "    or sstv 13n to cancel event"
echo " ***************************************************************************************"
echo 
echo 
echo " e   : exit"
echo 
echo " If you want to set event off, then type the number finished by 'n"
echo " ==> 1 (set event on)    ;   ==> 1n (set event off)"
echo " "
echo " Select the session you want to set in event, 'e' to exit ==> \c"
read sess
if [ "x-$sess" = "x-e" ];then
   exit
else
   var=`echo $sess | grep 'n'`
   if [ $? -eq 0 ];then
      SET_EVENT=OFF
      LEVEL=0
   else
      SET_EVENT=ON
   fi
   sess=`echo $sess | sed 's/n//'`
   LIGN=`head -$sess $FOUT | tail -1`
   OS_PID=`echo $LIGN | awk '{print $2}`
   if $SBINS/yesno.sh " to set event $EVENT level $LEVEL for $OS_PID "
      then
       var=`sqlplus  -s "$CONNECT_STRING" <<-EOF
       set pages 0 feed off head off verify off pause off
       select s.sid from v\\$session s, v\\$process p
       where s.paddr = p.addr
   --           and s.username != 'NULL'
              and p.spid = '$OS_PID';
	EOF`
       SID=`echo $var |awk '{print $1}'`
       if [ $SET_EVENT = ON ];then
          $SBINS/smenu_set_event_in_session.ksh $SID $EVENT $LEVEL
       else
          $SBINS/smenu_set_event_in_session.ksh $SID $EVENT 0
       fi
   else
      echo "Next time may be, life is so unpredictable ....."
   fi
fi
