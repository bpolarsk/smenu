#!/bin/sh
# program 
# Bernard Polarski
SBINS=${SBIN}/scripts
WK_SBIN=${SBIN}/module3/s6
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`

while true
do
clear
cat <<%


   -------------------------------------------------------------
   Date           : `date +%d/%m-%H:%M`         Host  : `hostname`
   Oracle SID     : $THE_ORACLE_SID     menu  : sm/3.6.7
   Last Selection : $LAST_SELECTION
   *************************************************************
   *                                                           *
   *                  Statspack                                *
   *                                                           *
   *************************************************************

      
         Select an option :
         ------------------
              1  :  List available statspack snapshots
              2  :  Run a statspack
              3  :  Display last measurement
              4  :  Display a previous measurement

             e ) exit

%
echo "  Your choice : \c"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-" ];then
   continue
fi
if [ "x-$choice" = "x-e" ];then
    break
fi

#---------------------- ch 1 --------------------------------------------
 if [ $choice -eq 1 ];then
        $WK_SBIN/smenu_show_stats_list.ksh
        echo "Press Any key to continue"
        read ff
 fi
#---------------------- ch 2 --------------------------------------------
 if [ $choice -eq 2 ];then

    cat <<EOF

        This scripts launch statspack sleep x seconds, run reportstat
        and let you review the report.txt file. 
        A copy of the execution is put in "$SBIN/smenu/tmp"
  
        Usage :  (shortcut : 'sstp')

                sstp -l 10 -s 500 -r 31

        Notes : 
                -l : Level of details. by default it is 10, possible is 5
                -s : Seconds to sleep between the 2 measurements
                    s=0 will take only one measurment and report using a previous
                        first measurement
                -r : Do not take additional measurment, but show last report
                    if r=value then show report for Second measurement value

                -v : Display available measurements


EOF
     if $SBINS/yesno.sh "do you want to take a new  measurement" DO Y
        then
        echo "  Level [10]        ==> \c"
        read var
        if [ "x-$LEVEL" = "x-" ];then
              LEVEL=10
        else
              LEVEL=$var
        fi
        echo "  Sleep [60]        ==> \c"
        read var
        if [ "x-$SLEEP" = "x-" ];then
              SLEEP=60
        else
              SLEEP=$var
        fi
        $WK_SBIN/smenu_statpack.ksh -l $LEVEL -s $SLEEP
        echo "Press Any key to continue"
        read ff
    fi
 fi
#---------------------- ch 3 --------------------------------------------
 if [ $choice -eq 3 ];then
        echo "  Snap ID to review   ==> \c"
        read SNAP
        if [ ! "x-$SNAP" = "x-" ];then
           $WK_SBIN/smenu_statpack.ksh -r $SNAP
        fi
#---------------------- ch 4 --------------------------------------------
 elif [ $choice -eq 4 ];then
        $WK_SBIN/smenu_statpack.ksh -r $SNAP
#---------------------- Done --------------------------------------------
fi
done
