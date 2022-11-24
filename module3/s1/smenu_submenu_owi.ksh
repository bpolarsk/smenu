#!/bin/sh
# program 
# Bernard Polarski
# 12-November-2005
#set -x
WK_SBIN=${SBIN}/module3/s1
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
SAMPLE_WORK_DIR=$SBIN/tmp
FSAVE=$SBIN/data/sampler_$ORACLE_SID.ini
if [ -f $FSAVE ];then
   SAMPLE_WORK_DIR=`grep ^SAMPLE_WORK_DIR $FSAVE | cut -f2 -d=`
fi
SAMPLE_WORK_DIR=${SAMPLE_WORK_DIR:-.}
LST_SPL=`ls $SAMPLE_WORK_DIR/sample_sql_w_*[0-9][0-9][0-9]  | sed 's/.*sample_sql_w_\(.*\)\.\([0-9][0-9]*\)/\1_\2/' | sort -u`
echo " "
PS3=' Select Sample ==> '
echo " "
echo " Available Samples :\n\n"
select SPL in ${LST_SPL}
   do
      if [[ -n ${SPL} ]]; then
         break
      else
         print -u2 "Invalid choice"
      fi
done
echo "SPL=$SPL"
while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.1
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                 Smenu Oracle Wait interface               *
   *                                                           *
   *************************************************************
   
    Sample              : $SPL            
    Sample file out dir : $SAMPLE_WORK_DIR   

           Select a sample
           ----------------
             1  :  Dsiplay Top 10 wait event

           Define values
           -------------

           d ) change sample work dir
           s ) Save this setting

     e ) exit


%

echo "  Your choice : \c"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
 
if [ "x-$choice" = "x-s" ];then
   cat $FSAVE | grep -v "SAMPLE_WORK_DIR=" > $FSAVE.1
   echo "SAMPLE_WORK_DIR=$SAMPLE_WORK_DIR" >> $FSAVE.1
   mv $FSAVE.1 $FSAVE
fi
if [ "x-$choice" = "x-d" ];then
   echo "SAMPLE_WORK_DIR=> \c"
   read SAMPLE_WORK_DIR
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_owi_top_10_event.ksh  -d $SAMPLE_WORK_DIR -s $SPL
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   echo "\n Press Any key to continue... : \c"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
