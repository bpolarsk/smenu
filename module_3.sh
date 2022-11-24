#!/usr/bin/ksh
#module_3.sh
# date : 08 June 2005
# B. Polarski
# set -xv
SBINS=$SBIN/scripts
SBIN2=${SBIN}/module3
HOST=`hostname`

while true
do

clear
choice=''
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
if [ "x-$ORACLE_SID" = "x-" ];then
   THE_ORACLE_SID="NO ORACLE SID!"
fi
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                   Database Utilities                      *
   *                                                           *
   *************************************************************

      
         1 ) Monitor DB - (sub)
         2 ) Data guard & transport tablespace   (sub)
         3 ) jobs and scheduler                  (sub)
         4 ) Advisor area                        (sub)
         5 ) Table Partionning & OWB             (sub)
         6 ) Statitisctics gathering             (sub)
         7 ) Oradebug dump                       (sub)
         8 ) Replication with Oracle Streams     (sub)
         9 ) List of utilities with menu         (sub)

     e ) exit

%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=`echo $choice | awk '{printf ("%-5.5s",$1)}'`

if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
      ksh $SBIN2/s1/smenu_menu_monitor.ksh
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
    ksh  $SBIN2/s2/smenu_menu_dg.ksh
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
    ksh $SBIN2/s3/smenu_menu_jobs.ksh
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
    ksh  $SBIN2/s4/smenu_menu_advisor.ksh
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
    ksh  $SBIN2/s5/smenu_menu_partitioning.ksh
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
    ksh  $SBIN2/s6/smenu_menu_stats.ksh
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
    ksh  $SBIN2/s7/smenu_menu_oradebug.ksh
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
    ksh  $SBIN2/s8/smenu_menu_streams.ksh
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
    ksh  $SBIN2/s9/smenu_menu_list_s9.ksh
fi
#---------------------- ch -----------------------------------------------------

done
