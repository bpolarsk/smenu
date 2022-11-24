#!/bin/sh
# Program 
# Bernard Polarski
# Creation  : 9-Decembre-2005
# Re-disign : 23-June-2008

WK_SBIN=${SBIN}/module3/s8
NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi



if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STR_PASS=${STR_PASS:-STRMADMIN}
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`


if [ -x $SBIN/scripts/passwd.env ];then
   S_USER=${S_USER:-SYS}
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
fi
CONNECT_STRING=${CONNECT_STRING:-"/ as sysdba"}
#-----------------------------------------------------------------------
function do_it
{
   ACTION=$1
   VAR=`get_queue_name`
   cpt=`echo $VAR |wc -w`
   if [ $cpt -eq 1 ];then
      SCHEMA_NAME=`echo $VAR | cut -f1 -d '.'`
      Q_NAME=`echo $VAR | cut -f2 -d '.'`
   else
     PS3=' Select schema name  ==> '
     select OWN_Q_NAME in $VAR"Cancel"
       do
            break
       done
   fi
   if [ -n "$OWN_Q_NAME" ];then
       if [ ! "$OWN_Q_NAME" = "Cancel" ];then
          if $SBINS/yesno.sh "to stop queue $OWN_Q_NAME"
             then
              echo
              echo
              Q_OWNER=`echo $OWN_Q_NAME | cut -f1 -d '.'`
              Q_NAME=`echo $OWN_Q_NAME | cut -f2 -d '.'`
              ksh $WK_SBIN/smenu_stream_aq.ksh -u $Q_OWNER -qn $Q_NAME -$ACTION -x
              echo $NN " Press Any key to continue... : " $NC
              read ff
          fi
       fi
   fi
}
#-----------------------------------------------------------------------
function get_queue_name
{
  ret=`sqlplus -s $CONNECT_STRING<<EOF
set lines 190 pages 0 feed off verify off pause off
select owner||'.'||name from dba_queues where owner not in ('SYS','SYSTEM','WMSYS');
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
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.8.4
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                 Streams : Advance Queues                  *
   *                                                           *
   *************************************************************
     
       STRMADMIN          : $STRMADMIN 

           --------------------------------------------------------------               -----------------------
              Advance Queing menu                                                        Shortcut at dot prompt
           --------------------------------------------------------------               -----------------------

             1  :  List Queues status                                                     aq -l
             2  :  list all queue                                                         aq -q
             3  :  list all buffered queues                                               aq -bq
             4  :  list buffered suscribers figures                                       aq -s
             5  :  list buffered publishers figures                                       aq -b
             6  :  list buffered metadata                                                 aq -sm
             7  :  list queues contents                                                   aq -lq
             8  :  list all queue tables and their real size in blocks                    aq -qt
             9  :  List size of all AQ\$ tables                                            aq -gm
 
             21  :  Create  Queue                                                         aq -cr
             22  :  Drop    Queue                                                         aq -drop

             30      :  Start   Queue                                                     aq -start
             31      :  Stop    Queue                                                     aq -stop


     e ) exit
%
echo 
echo $NN "  Your choice : " $NC
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -l 
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch2 -----------------------------------------------------
elif [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -q
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch3 -----------------------------------------------------
elif [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -bq
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch4 -----------------------------------------------------
elif [ "x-$choice" = "x-4" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -s
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch5 -----------------------------------------------------
elif [ "x-$choice" = "x-5" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -b
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch6 -----------------------------------------------------
elif [ "x-$choice" = "x-6" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -sm
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch7 -----------------------------------------------------
elif [ "x-$choice" = "x-7" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -lq
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch8 -----------------------------------------------------
elif [ "x-$choice" = "x-8" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -gm
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch9 -----------------------------------------------------
elif [ "x-$choice" = "x-9" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -qt
   echo $NN "\n Press Any key to continue... : " $NC
   read ff
#---------------------- ch21 ----------------------------------------------------
elif [ "x-$choice" = "x-21" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -l 
   echo "==================="
   echo "Create a  queue : "
   echo "==================="
   echo 
   do_it cr
#---------------------- ch22 ----------------------------------------------------
elif [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_stream_aq.ksh -l 
   echo "==================="
   echo "Drop queue : "
   echo "==================="
   echo 
   do_it drop
#---------------------- ch30 -----------------------------------------------------
elif [ "x-$choice" = "x-30" ];then
   clear
   ksh $WK_SBIN/smenu_stream_aq.ksh -l 
   echo "==================="
   echo "Start queue : "
   echo "==================="
   echo 
   do_it start
#---------------------- ch31 -----------------------------------------------------
elif [ "x-$choice" = "x-31" ];then
   clear
   ksh $WK_SBIN/smenu_stream_aq.ksh -l 
   echo "==================="
   echo "Stop queue : "
   echo "==================="
   echo 
   do_it stop
fi
#---------------------- Done ----------------------------------------------------
done
