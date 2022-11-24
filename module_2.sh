#!/bin/sh
#module_2.sh
#set -xv
SBINS=$SBIN/scripts
SBIN2=${SBIN}/module2
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
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/2
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                   Database info                           *
   *                                                           *
   *************************************************************

      
         1 ) Installation                      (sub)
         2 ) User session utilities            (sub)
         3 ) Role, audit & quotas              (sub)
         4 ) Table & index size report menu    (sub)
         5 ) Tablespace management             (sub)
         6 ) Sessions Events and buffers       (sub)
         7 ) Database Locking and latches      (sub)
         8 ) Global areas and datacache        (sub)
         9 ) Flashback, Rman                   (sub)


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
      $SBIN2/s1/smenu_menu_installation.ksh
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
      
      $SBIN2/s2/smenu_menu_session.ksh
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
      $SBIN2/s3/smenu_menu_sec_audit_role.ksh
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
      $SBIN2/s4/smenu_menu_table_size.sh
fi
#---------------------- ch5 -----------------------------------------------------
if [ "x-$choice" = "x-5" ];then
      $SBIN2/s5/smenu_menu_space_management.ksh
fi
#---------------------- ch6 -----------------------------------------------------
if [ "x-$choice" = "x-6" ];then
      $SBIN2/s6/smenu_menu_event.ksh
fi
#---------------------- ch7 -----------------------------------------------------
if [ "x-$choice" = "x-7" ];then
      $SBIN2/s7/smenu_menu_enqueue.ksh
fi
#---------------------- ch8 -----------------------------------------------------
if [ "x-$choice" = "x-8" ];then
      $SBIN2/s8/smenu_menu_sga.ksh
fi
#---------------------- ch9 -----------------------------------------------------
if [ "x-$choice" = "x-9" ];then
      $SBIN2/s9/smenu_menu_flash.ksh
fi
done
#---------------------- End -----------------------------------------------------



