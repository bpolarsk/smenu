#!/bin/sh
# program 
# Bernard Polarski
# 15-December-2006

WK_SBIN=${SBIN}/module3/s9
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.9
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                 Utilities without menu                    *
   *                                                           *
   *************************************************************
      

     The following are utilites for which no menu exits.
     You will need to use the shortcuts associated from the prompt.



     dbrep          repair block               : smenu_run_dbms_repair.ksh



%
   echo "\n Press Any key to return .. : \c"
   read ff
   return
done
