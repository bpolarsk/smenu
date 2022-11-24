#!/bin/sh
# program 
# Bernard Polarski
# 11-Agust-2005

NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi

WK_SBIN=${SBIN}/module3/s7
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear

cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.7
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                Oradebug & trace analyzer
   *                                                           *
   *************************************************************
      

           Information :
           -------------
             1  :  Dump control file
             2  :  Dump PGA for an sid


     e ) exit

%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_dump_control_file.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   echo " PID to dump PGA ==> \c"
   read  PID
   ksh $WK_SBIN/smenu_dump_processstate.ksh $PID
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
