#!/bin/sh
# program 
# Bernard Polarski
# 18-August-2005
#set -x
WK_SBIN=${SBIN}/module3/s3
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.5.4
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Drop broken subpartitions                *
   *                                                           *
   *************************************************************
     

           Working Tablespace       : $GOOD_TBS 
           owner                    : $OWNER
           Table                    : $WRK_TBL
           CURRENT GENERATED SCRIPT : $CURR_SCRIPTS

           Perform :
           -------------
             a  :  Define a working TBS
             o  :  Define the owner table
             t  :  Select a broken table

             1  :  Generate script to exchange one sub partitions
             2  :  Generate script to exchange all sub partitions


     e ) exit



%
echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
#---------------------- ch-a -----------------------------------------------------
if [ "x-$choice" = "x-a" ];then

   cat <<-%

      The exchange of partitions must be done using a sane tablespace. if you create the
      exchange partitions using a 'create table as select * from table', 
      chances are that you create a partiton in the same corrupted tablespace
      The exchange partition will then work but you exchanged a corrupted partition
      with a currted partition.
	%

   echo "Give a working tablespace name ==> \c" 
   read GOOD_TBS
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch-b -----------------------------------------------------
if [ "x-$choice" = "x-o" ];then
   echo "Owner ==> \c" 
   read OWNER
fi
#---------------------- ch-c -----------------------------------------------------
if [ "x-$choice" = "x-t" ];then
   echo "Give a Partitionned table name ==> \c" 
   read WRK_TBL
fi
#---------------------- ch-g -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_sub_gen_exch_subpart_script.ksh $GOOD_TBS $OWNER $WRK_TBL
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch4 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_sub_gen_scr_exch_all_subpart.ksh $GOOD_TBS $OWNER
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
