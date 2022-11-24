#!/usr/bin/ksh
# program 
# Barjasse Didier,Bernard Polarski
#set -xv
HOSTNAME=`hostname`
WK_SBIN=${SBIN}/module2/s7
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2.7
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *          Database Locking  & latch                        *
   *                                                           *
   *************************************************************
      
        Lock :
        -------

          1  :  Count lock type
          2  :  List locks
          3  :  locks mode, requested and id1, id2 parameters
          4  :  Blocking and blocked users
          5  :  object locked and lock mode held
          6  :  Waiters and object waited


        Latch :
        -------
         11 :   Latch Detail Report
         12 :   Report latch sleeps
         13 :   Report latch spin
         14 :   Report sub pool latch distribution in shared_pool
         15 :   Report latch name
         16 :   Report latch waiting
         17 :   Show children latch presence
         18 :   Show latch sleeps distrubtion
         19 :   display paralllel query slave availability
         20 :   Show libray cache 
         21 :   Show libray cache pin info

         h ) What is a latch 

     e ) exit

%
echo "  Your choice : \c"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-e" ];then
    break
fi
 
if [ "x-$choice" = "x-h" ];then
    view $WK_SBIN/smenu_latch.txt
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then

     $WK_SBIN/smenu_all_locks.ksh -e
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff
fi

#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then

     $WK_SBIN/smenu_all_locks.ksh -l
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
     $WK_SBIN/smenu_all_locks.ksh -p
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff
fi

#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
     $WK_SBIN/smenu_all_locks.ksh -b
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff
fi
#---------------------- ch5 ----------------------------------------------------
# 
if [ "x-$choice" = "x-5" ];then
     $WK_SBIN/smenu_all_locks.ksh -o
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff

fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
     $WK_SBIN/smenu_all_locks.ksh -w
     echo " "
     echo "\n Press Any key to continue... : \c"
     read ff
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
   : 
fi
#---------------------- ch8 -----------------------------------------------------
#---------------------- ch11 -----------------------------------------------------
if [ "x-$choice" = "x-11" ];then
      clear
     echo "\n\n\n\n\n\n\n\n"
         echo " "
         echo " "
         $WK_SBIN/smenu_all_latch.sh -a
         echo " "
         echo " --------------------------------------------------------------"
         echo " "
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      cd $WK_SBIN
      $WK_SBIN/smenu_all_latch.sh -i
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
      cd $WK_SBIN
      $WK_SBIN/smenu_all_latch.sh -s
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch14-----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
      cd $WK_SBIN
      $WK_SBIN/smenu_all_latch.sh -p
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
      cd $WK_SBIN
      $WK_SBIN/smenu_all_latch.sh -n
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch16 ----------------------------------------------------
if [ "x-$choice" = "x-16" ];then
      cd $WK_SBIN
      ksh $WK_SBIN/smenu_latch_wait.sh
      echo "\n Press Any key to continue... : \c"
      read ff
fi
#---------------------- ch17 -----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
      $WK_SBIN/smenu_all_latch.sh -c
         echo "\n Press Any key to continue... : \c"
         read ff
fi
#---------------------- ch18 -----------------------------------------------------
if [ "x-$choice" = "x-18" ];then
      $WK_SBIN/smenu_all_latch.sh
         echo "\n Press Any key to continue... : \c"
         read ff
fi
#---------------------- ch19 -----------------------------------------------------
if [ "x-$choice" = "x-19" ];then
         $WK_SBIN/smenu_show_pq_slave.ksh
         echo "\n Press Any key to continue... : \c"
         read ff
fi
#---------------------- ch20 -----------------------------------------------------
if [ "x-$choice" = "x-20" ];then
         $WK_SBIN/smenu_lc.ksh
         echo "\n Press Any key to continue... : \c"
         read ff
fi
#---------------------- ch21 -----------------------------------------------------
if [ "x-$choice" = "x-21" ];then
         $WK_SBIN/smenu_lc.ksh -p
         echo "\n Press Any key to continue... : \c"
         read ff
fi
#---------------------- Tips ----------------------------------------------------
done
