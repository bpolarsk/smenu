#!/bin/sh
# program 
#
#set -xv
WK_SBIN=${SBIN}/module3/s3

THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
x_choice=''
cat <<%

   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.5
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                     Database Jobs & Scheduler             *
   *                                                           *
   *************************************************************

   
       Oracle 9i :

         1  :  List Jobs Running on the database
         2  :  List Submitted jobs
         3  :  
         4  :  Remove a job
         5  :  Run a job
         6  :  List scheduled jobs

       Oracle 10g :

     e ) exit



%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
      echo "\n\n\n\n"
      cat <<EOF
	    This script reports all the jobs running

            Result in SMENU/tmp
EOF
        echo " "
        cd $WK_SBIN
        $WK_SBIN/smenu_jobs.ksh -lr
        echo " "
        echo " Result in SMENU/tmp "
        echo $NN " Press Any key to continue... : $NC"
        read ff
fi

#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
        $WK_SBIN/smenu_jobs.ksh -ls
        echo $NN "\n Press Any key to continue... :  $NC"
        read ff
fi
#---------------------- ch3 -----------------------------------------------------
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
        echo $NN "Job to remove ==> $NC"
        read JBID
        $WK_SBIN/smenu_jobs.ksh -remove $JBID
        echo $NN "\n Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
        echo $NN "Job to run ==> $NC"
        read JBID
        $WK_SBIN/smenu_jobs.ksh -r $JBID
        echo $NN "\n Press Any key to continue... : $NC"
        read ff
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
        $WK_SBIN/smenu_scheduler.ksh -l
        echo $NN "\n Press Any key to continue... : $NC"
        read ff
fi
done
