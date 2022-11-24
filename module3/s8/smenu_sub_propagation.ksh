#!/bin/sh
# program  "smenu_sub_propagation.ksh"
# Bernard Polarski
# initial    :  20-Jun-2008

NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi

WK_SBIN=${SBIN}/module3/s8
if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STR_PASS=${STR_PASS:-STRMADMIN}
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
#-----------------------------------------------------------------------
function get_propagation_name
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
select propagation_name from dba_propagation;
EOF`
echo $ret | tr '\n' ' '
}
#-----------------------------------------------------------------------


while true
do
clear

cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.8.3
   Last Selection : $LAST_SELECTION
   *************************************************************
     
             STRMADMIN USER                    : $STRMADMIN



           --------------------------------------------------------------               -----------------------
               Propagation  menu                                                         Shortcut at dot prompt
           --------------------------------------------------------------               -----------------------

             1  :  propagation status                                                     prop -l
             2  :  propagation schedules                                                  prop -lc
             3  :  queue to queues correspondancies                                       prop -lc
             4  :  statitics for propagations sender                                      prop -s
             5  :  statitics for propagations receiver                                    prop -r

            20  :  Set the propagation latency                                            prop -lat

            30     :     Start Propagation                                                prop -start
            31     :     Stop  Propagation                                                prop -stop

     e ) exit
%
echo 
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_stream_propagation.ksh -l
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch2 -----------------------------------------------------
elif [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_stream_propagation.ksh -lc
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch3 -----------------------------------------------------
elif [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_stream_propagation.ksh -lq
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch4 -----------------------------------------------------
elif [ "x-$choice" = "x-4" ];then
   ksh $WK_SBIN/smenu_stream_propagation.ksh -s
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch5 -----------------------------------------------------
elif [ "x-$choice" = "x-5" ];then
   ksh $WK_SBIN/smenu_stream_propagation.ksh -r
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch20 -----------------------------------------------------
elif [ "x-$choice" = "x-20" ];then
cat <<EOF

   The propagation latency is the amount of seconds after which, if nothing yet happened
   then Oracle must check the queue. Every LCR queued or dequeued, the count is restart, 
   so If your system is always busy, this parameter will have little effect. This parameter 
   does not control the time between the enqueue and the dequeue - anyway there is not such 
   parameter. It is just mere polling parameter


EOF
set -x
   VAR=`get_propagation_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      PROPAGATION_NAME=$VAR
   else
     PS3=' Select Propagation  ==> '
     select PROPAGATION_NAME in ${VAR}"Cancel"
       do
            break
       done
   fi
 
   if [ -n "$PROPAGATION_NAME" ];then
       if [ ! "$PROPAGATION_NAME" = "Cancel" ];then
           echo $NN " New value => " $NC 
           read new_value 
           ksh $WK_SBIN/smenu_stream_propagation.ksh -lat $new_value -pn $PROPAGATION_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff

#---------------------- ch30 -----------------------------------------------------
elif [ "x-$choice" = "x-30" ];then
   echo
   VAR=`get_propagation_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      PROPAGATION_NAME=$VAR
   else
     PS3=' Select Propagation  ==> '
     select PROPAGATION_NAME in ${VAR}"Cancel"
       do
            break
       done
   fi
   if [ -n "$PROPAGATION_NAME" ];then
       if [ ! "$PROPAGATION_NAME" = "Cancel" ];then
            ksh $WK_SBIN/smenu_stream_propagation.ksh -start $PROPAGATION_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
#---------------------- ch31 -----------------------------------------------------
elif [ "x-$choice" = "x-31" ];then
   echo
   VAR=`get_propagation_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      PROPAGATION_NAME=$VAR
   else
     PS3=' Select Propagation  ==> '
     select PROPAGATION_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$PROPAGATION_NAME" ];then
       if [ ! "$PROPAGATION_NAME" = "Cancel" ];then
          ksh $WK_SBIN/smenu_stream_propagation.ksh -stop $PROPAGATION_NAME -x
       fi
   fi
   echo "\n Press Any key to continue... : \c"
   read ff
fi

#---------------------- Done ----------------------------------------------------
done
