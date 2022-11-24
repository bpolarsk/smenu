#!/usr/bin/ksh
# program 
# Bernard Polarski
#set -xv
SBINS=${SBIN}/scripts
WK_SBIN=${SBIN}/module2/s6
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
NN=
NC=
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
else
    NC='\c'
fi

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
   *              System buffers and sessions Events           *
   *                                                           *
   *************************************************************
     Events :
     --------

            1  :   
            2  :   Report system events figures
            3  :   Report session events
            4  :   Report session wait 
            5  :   Show system waitstat (v\$waitstat)
            6  :   Show object accessed by sessions
            7  :   Report session waits by burst of 10
            8  :   report background events
            9  :   Report response time breakdown
     Db block buffer :
     -----------------
            10  :   Avg Scan of LRU for free buff
            12  :   Display DB Block buffer usage
            13  :   Display Unix filesystem log buffer size
            14  :   Test for the largest possible multiblock read
            15  :   Buffer busy waits file distribution
            17  :   Report buffer duplicated in DB_buffer per objects
            18  :   Report buffer distribution in DB buffer per pool (8+)
            19  :   Report buffer distribution by category
            20  :   Describe buffer pool in system
            21  :   Show table that would benefit of being pinned in mem
     statistics :
     -------------
            31  :  Show system stats
            32  :  Show system stats for a specific class
            33  :  Show system delta for a given duration (secs)

      e ) exit

%
echo $NN "  Your choice : $NC"
read choice
LAST_SELECTION=$choice

if [ "x-$choice" = "x-" ];then
   continue
fi
if [ "x-$choice" = "x-e" ];then
    break
fi

#---------------------- ch 1 -------------------------------------------
if [ $choice -eq 1 ];then

   echo "Press Any key to continue"
   read ff
#---------------------- ch 2 -------------------------------------------
elif [ $choice -eq 2 ];then
   $WK_SBIN/smenu_system_event.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 3 -------------------------------------------
elif [ $choice -eq 3 ];then
   $WK_SBIN/smenu_session_event.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 4 -------------------------------------------
elif [ $choice -eq 4 ];then
   $WK_SBIN/smenu_session_wait.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 5 -------------------------------------------
elif [ $choice -eq 5 ];then
   $SBIN/module2/s6/smenu_sys_stats.ksh -w
   echo "Press Any key to continue"
   read ff
#---------------------- ch 6 -------------------------------------------
elif [ $choice -eq 6 ];then
   $WK_SBIN/smenu_object_accessed.sh
   echo "Press Any key to continue"
   read ff
#---------------------- ch 7 -------------------------------------------
elif [ $choice -eq 7 ];then
   $WK_SBIN/smenu_session_wait.sh -t
   echo "Press Any key to continue"
   read ff
#---------------------- ch 8 -------------------------------------------
elif [ $choice -eq 8 ];then
   $SBIN/module2/s1/smenu_view_archive_mode.sh -bw
   echo "Press Any key to continue"
   read ff
#---------------------- ch 9 -------------------------------------------
elif [ $choice -eq 9 ];then
   $SBIN/module2/s2/smenu_sessions_overview.sh -cpu
   echo "Press Any key to continue"
   read ff
fi
#---------------------- ch10 -----------------------------------------------------
if [ "x-$choice" = "x-10" ];then
      $WK_SBIN/smenu_db_buffer.ksh -s
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch11 -----------------------------------------------------
#---------------------- ch12 -----------------------------------------------------
if [ "x-$choice" = "x-12" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -t
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch13 -----------------------------------------------------
if [ "x-$choice" = "x-13" ];then
      clear
      cat <<OUF

         This procedure return the Unix size (in bytes) of the buffer used by 
         your filesytem.  This value is very usefull in order to calculate 
         your log_buffer size (which should be a multiple of it).


OUF
      $WK_SBIN/smenu_db_buffer.ksh -f
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch14 -----------------------------------------------------
if [ "x-$choice" = "x-14" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -test
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch15 -----------------------------------------------------
if [ "x-$choice" = "x-15" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -w
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch16 -----------------------------------------------------
if [ "x-$choice" = "x-17" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -d
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch18 -----------------------------------------------------
if [ "x-$choice" = "x-18" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -p
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch19 -----------------------------------------------------
if [ "x-$choice" = "x-19" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -g
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch20 ----------------------------------------------------
if [ "x-$choice" = "x-20" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -r
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch21 ----------------------------------------------------
if [ "x-$choice" = "x-21" ];then
      clear
      $WK_SBIN/smenu_db_buffer.ksh -pin
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch31 ----------------------------------------------------
if [ "x-$choice" = "x-31" ];then
      clear
      $WK_SBIN/smenu_sys_stats.ksh -l
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch32 ----------------------------------------------------
if [ "x-$choice" = "x-32" ];then
      clear
      echo $NN "Class (1,8,32,64,128) => $NC"
      read CLASS
      $WK_SBIN/smenu_sys_stats.ksh  -c $CLASS
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
#---------------------- ch33 ----------------------------------------------------
if [ "x-$choice" = "x-33" ];then
      clear
      echo $NN "Class (1,8,32,64,128 - <ENTER of all>) => $NC"
      read CLASS
      if [ -n "$CLASS" ];then
         F_CLASS="-c $CLASS"
      else
         unset F_CLASS
      fi
      echo $NN "Duration of measurments (in seconds ) => $NC"
      read SECS
      $WK_SBIN/smenu_sys_stats.ksh -d $SECS  $F_CLASS
      echo $NN " Press Any key to continue... : $NC"
      read ff
fi
done
