#!/bin/sh
# program 
# Bernard Polarski
# 8-Juillet-2005
#set -x
WK_SBIN=${SBIN}/module3/s5
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
RT_USER=`cat $SBIN/data/owb_info.txt | grep $ORACLE_SID:RT_USER=| cut -f2 -d=`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.5
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *    Table Partion management & Oracle Warhouse builder     *
   *                                                           *
   *************************************************************
      

           Table Partitions :
           -------------------
             1  :  Show partitions for a table 
             2  :  Generate a create table script limited to first partition
             3  :  Show Missing subpartitions and partitions for a table
             4  :  Drop broken/non-existent table (sub)partitions            (sub)



     e ) exit



%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   echo " Table_name ==> \c"
   read ftable
   $SBIN/module2/s4/smenu_desc_table.ksh -t $ftable -p
   unset ftable
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
    cat <<-%

         This script will extract a table ddl from a partitioned table but only up
         to the first partition, including the subpartition. It is used to create
         the dummy table for the exchange partition for a composite partitions

	%

   ksh $WK_SBIN/smenu_get_sub_part_ddl.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   ksh $WK_SBIN/smenu_show_missing_tab_parts.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-4" ];then
   ksh $WK_SBIN/smenu_submenu_drop_broken_part.ksh
   echo "\n Press Any key to continue... : \c"
   read ff
fi

#---------------------- ch10 -----------------------------------------------------
#---------------------- Done ----------------------------------------------------
done
