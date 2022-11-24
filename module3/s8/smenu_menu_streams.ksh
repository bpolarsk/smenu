#!/bin/sh
# program : smenu_menu_streams.ksh
# Bernard Polarski
# 29-November-2005
# Re-disigned 18-June-2008

WK_SBIN=${SBIN}/module3/s8
if [ -f $SBIN/data/stream_$ORACLE_SID.txt ];then
   STRMADMIN=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STRMADMIN=| cut -f2 -d=`
   STR_PASS=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep STR_PASS=| cut -f2 -d=`
   DEF_SID=`cat $SBIN/data/stream_$ORACLE_SID.txt | grep DEF_SID=| cut -f2 -d=`
fi
STRMADMIN=${STRMADMIN:-STRMADMIN}
STR_PASS=${STR_PASS:-STRMADMIN}
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

while true
do
clear

cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.8
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                 Oracle Replication with Streams           *
   *                                                           *
   *************************************************************
     


          STRMADMIN USER      : $STRMADMIN          Setting (s) to manage this user 
 




           --------------------------------------------------------------
                                 Options 
           --------------------------------------------------------------

             1  :  Capture Process                       (sub)
             2  :  Apply Process                         (sub)
             3  :  Propagation Process                   (sub)
             4  :  Manage Queues                         (sub)

             s  :  Setting                               (sub)


     e ) exit
%
echo 
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
#---------------------- (s) -----------------------------------------------------
elif [ "x-$choice" = "x-s" ];then
   ksh $SBIN/module3/s8/smenu_sub_setting.ksh 
#---------------------- ch1 -----------------------------------------------------
elif [ "x-$choice" = "x-1" ];then
   ksh $SBIN/module3/s8/smenu_sub_capture.ksh 
#---------------------- ch2 -----------------------------------------------------
elif [ "x-$choice" = "x-2" ];then
   ksh $SBIN/module3/s8/smenu_sub_apply.ksh 
#---------------------- ch3 -----------------------------------------------------
elif [ "x-$choice" = "x-3" ];then
   ksh $SBIN/module3/s8/smenu_sub_propagation.ksh 
#---------------------- ch4 -----------------------------------------------------
elif [ "x-$choice" = "x-4" ];then
   ksh $SBIN/module3/s8/smenu_sub_aq.ksh 
fi
#---------------------- Done ----------------------------------------------------
done
