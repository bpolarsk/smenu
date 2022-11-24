#!/bin/sh
# program 
# Bernard Polarski
# 01-October-2005

WK_SBIN=${SBIN}/module3/s6

typeset -u STAT_SCHEMA
typeset -u STAT_TABLE
STAT_TABLE=sm_stattab
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.6
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                    Statitics Management                   *
   *                                                           *
   *************************************************************
      
      STATS TABLE    : $STAT_TABLE
      MANAGED SCHEMA : $STAT_SCHEMA

           Information :
           -------------
             1  :  Show objects without stats in the schema
             2  :  List statst for a table



     e ) exit
     t ) Stat table : $STAT_TABLE
     u ) schema     : $STAT_SCHEMA

%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
if [ "x-$choice" = "x-t" ];then
      unset STAT_TABLE
      echo "target stat table ==> \c"
      read STAT_TABLE
fi
if [ "x-$choice" = "x-u" ];then
      unset STAT_SCHEMA
      echo "Manage stat for Schema  ==> \c"
      read STAT_SCHEMA
fi
 
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   if [ -z "$STAT_SCHEMA" ];then
      echo "Owner ==>  \c"
      read STAT_SCHEMA
   fi
   ksh $WK_SBIN/smenu_list_obj_no_stat.ksh $STAT_SCHEMA
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   if [ -z "$STAT_SCHEMA" ];then
      echo "Owner ==>  \c"
      read STAT_SCHEMA
   fi
   echo "Table ==> \c"
   read TBL
   ksh $SBIN/module2/s4/smenu_desc_table.ksh -u $STAT_SCHEMA -t $TBL -s
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
