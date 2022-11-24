#!/bin/sh
# program 
# Bernard Polarski
# 20-Juin-2005

WK_SBIN=${SBIN}/module3/s4
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.4
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                    Advisor area                           *
   *                                                           *
   *************************************************************
      

           Information :
           -------------
             1  :  Show most recent advisor action
             2  :  submit a slq file to SQL advisor
             3  :
             4  :  Run tkprof
             5  :  Set a Event trace 10046 
             6  :  Run tkprof for event
             7  :  run statpack                     (sub)



     e ) exit



%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_show_adv_action.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_submit_sql_to_adv.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
   ksh $SBINS/smenu_choose_tkprof.sh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
   ksh $WK_SBIN/smenu_choose_session_to_set_event.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
   ksh $SBINS/smenu_choose_tkprof.sh v
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
   ksh $WK_SBIN/smenu_sub_statspack.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------

#---------------------- Done ----------------------------------------------------
done
