#!/bin/sh
# program : smenu_menu_monitor.ksh
# Bernard Polarski
# 20-Agust-2005
# -----------------------------------------------------------------------------------------------
# Notes : Driving script for the fake 'spl' shortcuts. this scripts behave either like a menu
#        if no argument are given, or analyze the argument and call another scripts if argument
#        are given 
#        Called scripts may be : 'smenu_generate_sampler.ksh'  --> generates the sample
#                                'smenu_owi.ksh'               --> Query the sample
#                                'smenu_sample_to_db.ksh'      --> upload the sample in another DB
# it is not necessary to upload the sample in version 9ir2+, as smenu_owi.ksh can mount the ascii 
# files, however, if you create the sample using the perl connection, that is to say you are not
# creating the ascii file on the Oracle DB Server, then you can't use the DIRECTORY objects to
# read the ascii files. The only option is then to upload the ascii file into a DB.
# -----------------------------------------------------------------------------------------------
# set -x
ALL_VAR="$@"
typeset -u PARMS
PARMS=`echo $ALL_VAR | awk '{print $1}'`
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
    unset NC
else
    NC='\c'
    unset NN
fi
# ---------------------------------------------------------------------

WK_SBIN=${SBIN}/module3/s1
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
SAMPLE_WORK_DIR=$SBIN/tmp
LEN_SEC=1800
FSAVE=$SBIN/data/sampler_$ORACLE_SID.ini
if [ -f $FSAVE ];then
   SAMPLE_WORK_DIR=`grep ^SAMPLE_WORK_DIR $FSAVE | cut -f2 -d=`
   INTERVAL_WAIT=`grep ^INTERVAL_WAIT $FSAVE | cut -f2 -d=`
   COLOR=`grep ^COLOR $FSAVE | cut -f2 -d=`
   LEN_SEC=`grep ^LEN_SEC $FSAVE | cut -f2 -d=`
   EXEC_IMMED=`grep ^EXEC_IMMED $FSAVE | cut -f2 -d=`
   INTERVAL_DELTA=`grep ^INTERVAL_DELTA $FSAVE | cut -f2 -d=`
fi
COLOR=${COLOR:-lblue lred lyellow green}
INTERVAL_WAIT=${INTERVAL_WAIT:-1}
INTERVAL_DELTA=${INTERVAL_DELTA:-60}
EXEC_IMMED=${EXEC_IMMED:-YES}
if [ "$EXEC_IMMED" = "YES" ];then
   X="-x"
else
  unset X
fi
LEN_SEC=${LEN_SEC:--1}
if [ "$INTERVAL_DELTA" = "-1" ];then
     unset FIG
else
     FIG="-s $INTERVAL_DELTA"
fi
# ---------------------------------------------------------------
# implement default if called from command line
# ---------------------------------------------------------------
if [ -n "$ALL_VAR" ];then
   if [ "$PARMS" = "STOP" ];then
     echo stop > $SAMPLE_WORK_DIR/sem_sql_w_$ORACLE_SID.txt
     exit
   elif [ "$PARMS" = "START" ];then
     while [ -n "$1" ]
     do
         PAR=`echo $ALL_VAR | awk '{print $1}'`
         case $1 in
              -l ) LEN_SEC=$2 ; shift ;;
           -perl ) F_PERL=-perl ;;
              -o ) SID=$2; shift ;;
              -p ) F_PASSWD="-p "$2; shift ;;
           start ) : ;;
              -s ) INTERVAL_DELTA=$2 ; shift ;;
              -i ) INTERVAL_WAIT=$2 ; shift ;;
              -u ) F_USER="-u "$2; shift ;;
               * ) SID=$1 ;;
         esac
         shift
     done
     SID=${SID:-$ORACLE_SID}
     ksh $WK_SBIN/smenu_generate_sampler.ksh -i $INTERVAL_WAIT -d $SAMPLE_WORK_DIR -l $LEN_SEC $X $FIG -s $INTERVAL_DELTA -o $SID $F_USER $F_PASSWD $F_PERL
     exit
  elif [ -z ${PARMS##*RENAME*} ];then
     while [ -n "$1" ]
     do
         PAR=`echo $ALL_VAR | awk '{print $1}'`
         case $1 in
          -o ) OLD_SID=$2; shift ;;
          -n ) NEW_SID=$2; shift ;;
          -d ) OLD_DATE=$2; shift ;;
         -dir) FDIR=$2; shift ;;
         esac
         shift
    done   
    NEW_SID=${NEW_SID:-$ORACLE_SID}
    OLD_DATE=${OLD_DATE:-\*}
    FDIR=${FDIR:-$SBIN/tmp} 
    cd $FDIR
    for file in `ls sample_*${OLD_SID}.${OLD_DATE}`
    do
       NEW_FILE=`echo $file | sed 's/'$OLD_SID'/'$NEW_SID'/'`
       mv $file $NEW_FILE
    done
    exit
  elif [ -z ${PARMS##*PACK*} ];then
     while [ -n "$1" ]
     do
         PAR=`echo $ALL_VAR | awk '{print $1}'`
         case $1 in
          -o ) OLD_SID=$2; shift ;;
          -d ) OLD_DATE="$OLD_DATE $2"; shift ;;
         -dir) FDIR=$2; shift ;;
         esac
         shift
    done   
    OLD_SID=${OLD_SID:-$ORACLE_SID}
    NEW_SID=${ORACLE_SID}
    FDIR=${FDIR:-$SBIN/tmp} 
    cd $FDIR
    if [ -z "$OLD_DATE" ];then
          OLD_DATE=`ls sample_sql_w_${NEW_SID}.* | cut -f2 -d'.'`
    fi
    NEW_DATE=`date +%m%d%H%M`
    >  sample_sql_w_${NEW_SID}.$NEW_DATE
    >  sample_txt_w_${NEW_SID}.$NEW_DATE
    >  sample_sys_w_${NEW_SID}.$NEW_DATE
    >  sample_delta_w_${NEW_SID}.$NEW_DATE
    for EXT_DATE in $OLD_DATE
    do
       SPL_W="$SPL_W sample_sql_w_${OLD_SID}.$EXT_DATE"
       SPL_S="$SPL_S sample_sys_w_${OLD_SID}.$EXT_DATE"
       SPL_T="$SPL_T sample_txt_w_${OLD_SID}.$EXT_DATE"
       SPL_D="$SPL_D sample_delta_w_${OLD_SID}.$EXT_DATE"
    done
    echo " Collapsing SQL_W for $OLD_DATE ..."
    cat $SPL_W            >>   sample_sql_w_${NEW_SID}.$NEW_DATE
    echo "Collapsing SQL_T for $OLD_DATE ..."
    cat $SPL_T  | sort -u >>   sample_txt_w_${NEW_SID}.$NEW_DATE
    echo "Collapsing SQL_S for $OLD_DATE ..."
    cat $SPL_S            >>   sample_sys_w_${NEW_SID}.$NEW_DATE
    echo "Collapsing SQL_D for $OLD_DATE ..."
    cat $SPL_D            >>   sample_delta_w_${NEW_SID}.$NEW_DATE
    exit
  
  # --------------------------------------------------------------------------------
  # it is not a start of sampler nor a maintenance on ascii files, so it is a query
  # --------------------------------------------------------------------------------
  else
      ksh $WK_SBIN/smenu_owi.ksh $ALL_VAR
      exit
  fi
fi
# ----------------------------------------------------------------------------------
# No argument  given to 'spl' so we call  the configuration and setting of spl menu
# ----------------------------------------------------------------------------------
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
   *                 Sample Oracle waits interface             *
   *                                                           *
   *************************************************************
   

    Sample file out dir : $SAMPLE_WORK_DIR   
    duration of sample  : $LEN_SEC              (-1 => infinite)
    Interval wait state : (s) $INTERVAL_WAIT
    Dump SQL Fig every  : (s) $INTERVAL_DELTA   (-1 => no delta)
    Execution immediate : $EXEC_IMMED
    Colors for Bar charts : $COLOR

           Sample:
           --------
             1  :  start sampler all wait state
             2  :  start sampler for sql with wait state
             3  :  stop samplers for this instance 

           Define values
           -------------

           d ) change sample work dir
           l ) change sample duration
           i ) change interval wait state
           n ) change interval delta stat dump
           c ) change colors for bar charts
           x ) toggle execution immediate
           s ) Save this setting

     e ) exit
     h ) help


%
echo $NN "  Your choice : $NC"
read choice


if [ "x-$choice" = "x-e" ];then
    break
fi
if [ "x-$choice" = "x-h" ];then
      $WK_SBIN/smenu_owi.ksh -h
      echo $NN "\n Press Any key to continue... : $NC"
      read ff
fi
 
if [ "x-$choice" = "x-s" ];then
   echo "INTERVAL_WAIT=$INTERVAL_WAIT"      > $FSAVE
   echo "INTERVAL_DELTA=$INTERVAL_DELTA"      >> $FSAVE
   echo "SAMPLE_WORK_DIR=$SAMPLE_WORK_DIR" >> $FSAVE
   echo "LEN_SEC=$LEN_SEC" >> $FSAVE
   echo "EXEC_IMMED=$EXEC_IMMED" >> $FSAVE
   echo "COLOR=$COLOR"    >> $FSAVE
fi
if [ "x-$choice" = "x-l" ];then
   echo $NN "Length in seconds=> $NC"
   read LEN_SEC
fi
if [ "x-$choice" = "x-n" ];then
   echo $NN "Length in seconds=> $NC"
   read INTERVAL_DELTA
   if [ "$INTERVAL_DELTA" = "-1" ];then
         unset FIG
   else
          FIG="-a $INTERVAL_DELTA"
   fi
fi
if [ "x-$choice" = "x-i" ];then
   echo $NN "INTERVAL_WAIT=> $NC"
   read INTERVAL_WAIT
fi
if [ "x-$choice" = "x-c" ];then
   cat <<EOF

     You need to provide 4 colors among this list :

     white, lgray, gray, dgray, black, lblue, blue, dblue, gold, lyellow, yellow, dyellow, 
     lgreen, green, dgreen, lred, red, dred, lpurple, purple, dpurple, lorange, orange, pink, 
     dpink, marine, cyan, lbrown, dbrown.

      color order will determine the following :

        1st : ROWS_PROCESSED
        2nd : DISK_READS
        3rd : BUFFER GETS
        4th : EXECUTIONS

EOF
   echo $NN "COLOR LIST => $NC"
   read COLOR
fi
if [ "x-$choice" = "x-d" ];then
   echo $NN "SAMPLE_WORK_DIR=> $NC"
   read SAMPLE_WORK_DIR
fi
if [ "x-$choice" = "x-x" ];then
   if [ $EXEC_IMMED = 'YES' ];then
        EXEC_IMMED=NO
        unset X
   else
        EXEC_IMMED=YES
        X='-x'
   fi
fi
#---------------------- ch1 -----------------------------------------------------
if [ "x-$choice" = "x-1" ];then
   ksh $WK_SBIN/smenu_sampler_wait_state.ksh -i $INTERVAL_WAIT -d $SAMPLE_WORK_DIR -l $LEN_SEC $X
   echo "\n Press Any key to continue... : "
   read ff
fi
#---------------------- ch2 -----------------------------------------------------
if [ "x-$choice" = "x-2" ];then
   ksh $WK_SBIN/smenu_generate_sampler.ksh -i $INTERVAL_WAIT -d $SAMPLE_WORK_DIR -l $LEN_SEC $X $FIG -s $INTERVAL_DELTA
   echo $NN "\n Press Any key to continue... : $NC"
   read ff
fi
#---------------------- ch3 -----------------------------------------------------
if [ "x-$choice" = "x-3" ];then
   echo stop > $SAMPLE_WORK_DIR/sem_sql_w_$ORACLE_SID.txt
   echo $NN "\n Press Any key to continue... : $NC"
   read ff
fi
#---------------------- Done ----------------------------------------------------
done
