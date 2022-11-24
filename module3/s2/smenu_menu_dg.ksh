#!/bin/sh
# program 
# Bernard Polarski
# 04-Agust-2005

WK_SBIN=${SBIN}/module3/s2
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.2
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                 Dataguard & Transport Tablespace          *
   *                                                           *
   *************************************************************
      

           Physical Data Guard :
           -i-------------------
             1  :  List main data guards parameters value
             2  :  Show applied archive logs
             3  :  Report log ship to standby (run on primary)
             4  :  Report Dataguard status

           Logical Data Guard :
           --------------------
    
            5   :  List logical status
            6   :  List logical reader status

           Transport Tablespace:
           ---------------------
            10  :  Check if a tablespace is self contained
            11  :  Transport a set of tablespace : Create metadata
            12  :  Transport a set of tablespace : Import metadata

     e ) exit



%
echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_list_std_param.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_show_applied_arc.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_show_logical_dg.ksh -lerr
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
   ksh $WK_SBIN/smenu_show_logical_dg.ksh -l
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
   ksh $WK_SBIN/smenu_show_logical_dg.ksh -l
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
   ksh $WK_SBIN/smenu_show_logical_dg.ksh -c
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
   ksh $WK_SBIN/smenu_transportable_tbs.ksh
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
   ksh $WK_SBIN/smenu_transportable_tbs.ksh -e
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
   ksh $WK_SBIN/smenu_transportable_tbs.ksh -i
   echo $NN " Press Any key to continue... : $NC"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
