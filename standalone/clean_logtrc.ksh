#!/bin/sh
# set -x
# date   : 05-Juillet-2005
# Author : bpolarski
# name   : clean_logtrc.ksh
# version: 1.0
# history:   22 September 2005  :  Added the capacity to remove a file after a certain number of days
#                                  This is most usefull to manage alert.logs and slqnet.logs
# purpose: This script will track all files older than n days and move them in
#          in a week days directory structure so that we don't have to take care about purge
#          By default It will create if not exists a directory at the same level than
#          ADMIN_DIR named bk_logtrc with 7 directories : 'mon tue wed thu fri sat sun'.
#          in each directory you will find a file named clean_date.txt that contain the date
#          of the last time when the clean has been performed. If you launch the script twice
#          the same day, the script correctly purge and move the logs the first time and do nothing 
#          the second and successive time.
# 
#          The script takes its input from an ini file with a section for each SID or pseudo SID
#
#          There is no connection to the DB to avoid maintenance in this domain. You are more likely 
#          to change a passwd than a DB directory file structure. So the target udump and co is encoded 
#          and used. It could have been retrieved from v$parameter but this would requiere a connection 
#          to the DB, minatenance of the ini file each time the pass is changed.
#
#          -You can specify any directory or extention for the files to track and move
#          here is a description of the ini file :
# 
#  Each section must be put at begining of line, start with the SID (or dummy SID)
#  have an ADMIN_DIR where the log file and trace file dir are supposed to be. The variable ADMIN_DIR
#  will also determine the location of the directory 'bk_logtrc' that will be created.
#
# -Extention monitored by default are ' *.trc *.log *.gz'
#  The files move and purge is done for each line 'DIR=' using either the default parameters (hardcoded),
#  the section parameter (section overload) or the line parameter following the DIR declaration.
#
# [emrep10]    # This is a section, usually an SID, but can only be a container also
# ADMIN_DIR=
# FILE_DAYS=   # scope section override any default setting hardcoded or given by -t
# CORE_DAYS=   # scope section override any default setting hardcoded or given by -c
# EXT='\\*'    # default for the section overide general setting

# DIR=udump

# DIR=cdump
# CORE_DAYS=   # scope dir override all
# EXT='txt'    # scope dir override all

# DIR=bdump
# EXT='trc'
# ---------------------------------------------------------------------------------------
# if you want to have in the bdump directory, the alert.log on 20 days and all trc file on 5 days 
# you need to declare twice the directory
#
# DIR=bdump
# FILE_DAYS=20
# EXT=log
# DIR=bdump
# FILE_DAYS=7
# EXT=trc
# DIR=bdump
# FILE_CHECK=alert.log    Truncate this file after 14 days since last measurement
# FILE_AGE=14
# ---------------------------------------------------------------------------------------
# if you want to have all files in a directory :
# DIR=mydir
# EXT=\\* 
#

# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
#                     Functions
# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
function clean_dir
{
#set -x
    # Check if the directory really exists
    cd $BK_DIR
    for i in `ls $BK_DIR`    # do not use rm *, if there are many files it will fail to build the list
    do
      rm -f $i
    done
    cd -
}
# ---------------------------------------------------------------------------------------
function process_files
{
#set -x
  typeset -i ret=0
  if [ -n "$EXT" ];then
     for ext in `echo "$EXT"`
     do
         if [ "$TRACE" = 1 ] ;then
            echo "Cheking files $ext type in $ADMIN_DIR/$TARGET_DIR"
         fi
         if [ "$EXT" = "\*" ];then
            REXT=\*
         else
            REXT=\*.$ext
         fi
         ret=`find $ADMIN_DIR/$TARGET_DIR/$REXT -mtime +$FILE_DAYS 2>/dev/null| wc -l`
         if [ $ret -gt 0 ];then
            echo "Moving all file older than $FILE_DAYS and type '$ext' to $BK_DIR"
            find $ADMIN_DIR/$TARGET_DIR/$REXT -mtime +$FILE_DAYS | while read file
            do
            if [ -f $file ];then
              if [ "$TRACE" = 1 ] ;then
                 echo "Moving `basename $file` ==> $BK_DIR"
              fi
              mv $file $BK_DIR/$TARGET_DIR.`basename $file`
           fi
           done 2>/dev/null
           for file in `ls $BK_DIR/$REXT 2>&1`
           do
              gzip -f $file  1>/dev/null 2>&1
           done
         fi
     done
  fi
}
# ---------------------------------------------------------------------------------------
function calc_date 
{
#set -x
  YYYY=`echo $1 | cut -c1-4`
  MM=`echo $1 | cut -c5-6`
  DD=`echo $1 | cut -c7-8`
  OFFSET=$2

  STRY=312831303130313130313031
  END_POS=`expr $MM \* 2`
  START_POS=`expr $END_POS - 1`
  MM_LENGTH=`echo $STRY | cut -c$START_POS-$END_POS`
  TARGET_DAY=`expr $DD + $OFFSET`
  if [ $TARGET_DAY -gt $MM_LENGTH ];then
        RET_MM=`expr $MM + 1`
        if [ $RET_MM -eq 13 ];then
              RET_MM=1
              RET_YYYY=`expr $YYYY + 1`
        else
              RET_YYYY=$YYYY
        fi
        if [ $RET_MM -lt 10 ];then
             RET_MM='0'$RET_MM
        fi
        RET_DD=`expr $TARGET_DAY - $MM_LENGTH`
  else
      RET_YYYY=$YYYY
      RET_MM=$MM
      RET_DD=$TARGET_DAY
   fi
   if [ $RET_DD -lt 10 ];then
        RET_DD='0'$RET_DD
   fi
   echo ${RET_YYYY}${RET_MM}${RET_DD}
}
# ---------------------------------------------------------------------------------------
function process_check_files
{
#set -x

  cd $LOCAL_ADMIN_DIR/$TARGET_DIR
  if [ -f $FILE_CHECK_INI ];then
     echo "Checking if $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK has reach its limit of $FILE_AGE days"
     RET=`grep $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK $FILE_CHECK_INI`
     if [ $? -eq 0 ];then
        CUT_OFF_DATE=`echo $RET | awk '{print $2}'`
        MAX_DATE=`calc_date $CUT_OFF_DATE $FILE_AGE`
        TODAY_DATE=`date +%Y%m%d`
        if  [ $MAX_DATE -lt $TODAY_DATE ];then
            echo "File $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK must be archived"
            TARGET_FILE=$LOCAL_ADMIN_DIR/$TARGET_DIR/${TODAY_DATE}_$FILE_CHECK
            # first revision I used 'mv' but then process follow the file under is new name
            # It seems that processes grep and cache the Inode, not the name.
            cp $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK $TARGET_FILE
            echo "# Recreated by clean_trc `date`" > $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK
            #  ---------------- updating now the dat file --------------------
            pos=`grep -n $LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK $FILE_CHECK_INI | cut -f1 -d:`
            sed '1,'$pos'd' $FILE_CHECK_INI > /tmp/ff$$
            mv /tmp/ff$$ $FILE_CHECK_INI
            echo "$LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK `date +%Y%m%d`" >> $FILE_CHECK_INI
        else
          : # nothing to do  today, date is still in range
        fi
     else
        # file was not found, so we add it
        echo "$LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK `date +%Y%m%d`" >> $FILE_CHECK_INI
     fi
  else
     # add the local date
     echo "$LOCAL_ADMIN_DIR/$TARGET_DIR/$FILE_CHECK `date +%Y%m%d`" > $FILE_CHECK_INI
  fi
}
# ---------------------------------------------------------------------------------------
function process_cores
{
#set -x
  cd $LOCAL_ADMIN_DIR/$TARGET_DIR
  ret=`find $ADMIN_DIR/$TARGET_DIR -mtime +$CORE_DAYS -name "core_*" -prune 2>/dev/null| wc -l`
  if [ $ret -gt 0 ];then
     find $LOCAL_ADMIN_DIR/$TARGET_DIR -mtime +$CORE_DAYS -name "core_*" -prune -exec ls -d {} \; | while read a
     do
       echo "Suppressing $a"
       if [ -d $a ];then
         rm -rf $a
       fi
     done
  fi
}
# ---------------------------------------------------------------------------------------
function do_job
{
#set -x
 LOCAL_ADMIN_DIR=$1
 TARGET_DIR=$2
 echo
 day=`date +%a`
 BK_DIR=$LOCAL_ADMIN_DIR/bk_logtrc/$day
 if [ ! -d $BK_DIR ];then
    mkdir -p $BK_DIR
    if [ $? -ne 0 ];then
       echo " Error : cannot access $TARGET directory"
       return
    fi
    cd -
 fi
 if [ -f $BK_DIR/clean_date.txt ];then
    clean_date=`cat $BK_DIR/clean_date.txt`
 elif [ -f $BK_DIR/clean_date.txt.gz ];then
    # if somebody used \\* as extention, all files are compressed
    clean_date=`gunzip -c $BK_DIR/clean_date.txt`
 fi
 if [ "$clean_date"  = "`date +%d%m%Y`" ];then
    unset clean_date
 else
    clean_dir
    echo "`date +%d%m%Y`" > $BK_DIR/clean_date.txt
 fi
 if [ -n "$FILE_CHECK" ];then
    process_check_files
    unset FILE_CHECK
    unset FILE_AGE
 else
   process_cores
   process_files
 fi
}
# ---------------------------------------------------------------------------------------
function show_help
{

  cat <<EOF

           clean_log_trc.ksh -c [nnn] -f [full_path inifile]
                             -a [ADMIN_DIR ] -d [DIR to purge]
                             -e [EXT to purge] -v -h
 
             Parameters :   -c delete the core_nnnnn directory older than nn days
                            -t purge file older than [nnn]
                            -a provide an ADMIN_DIR
                            -d provile a directory to purge
                            -e provide an extention file name to process
                            -f read command from file <full path inifile> 
                            -v verbose
EOF
}
# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
#
#                            main 
#
# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------

# -----------------  default value section
TRACE=0
DEFAULT_CORE_DAYS="3"
DEFAULT_FILE_DAYS="7"
DEFAULT_EXT="trc log gz"
CORE_DAYS=$DEFAULT_CORE_DAYS
FILE_DAYS=$DEFAULT_FILE_DAYS
EXT=$DEFAULT_EXT


while getopts f:d:c:t:a:e:vh ARG
 do
  case $ARG in
     f ) INIFILE=$OPTARG;;
     c ) CORE_DAYS=$OPTARG ;;
     t ) FILE_DAYS=$OPTARG ;; 
     e ) EXT=$OPTARG;;
     a ) ADMIN_DIR=$OPTARG;;
     d ) TARGET_DIR=`basename $OPTARG`;;
     v ) TRACE=1 ;;
     h ) show_help 
         exit;;
  esac
done


# let's read the ini file an call functions for each SID we find
if [ -f "$INIFILE" ];then

FILE_CHECK_INI=`dirname $INIFILE`/check_logtrc.dat

#set -x
# Thanks to posix, on SUN and Linux, any variable modified into a 'while read' is lost 
# outside the loop , so we avoid the 'while read' and manage the read, line per line manually
typeset -i nbr_lines=0
typeset -i cpt=1

nbr_lines=`cat $INIFILE | grep -v ^# |  wc -l`   
while [ $cpt -le $nbr_lines ]
do
  line=`cat $INIFILE | grep -v ^# | head -$cpt |tail -1`
  cpt=$cpt+1
  if [ -z "$line" ];then
    continue
  fi
  echo $line | grep  "^\[" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
     # We found a section
     echo "---------------------------------------------"
     if [ -n "$OLD_SECTION" ] ;then
        do_job $ADMIN_DIR $OLD_DIR 
        # reset all variables between two sections 
        unset ADMIN_DIR
        unset OLD_DIR
        unset DIR
        CORE_DAYS=$DEFAULT_CORE_DAYS
        FILE_DAYS=$DEFAULT_FILE_DAYS
        EXT=$DEFAULT_EXT
     fi
     OLD_SECTION=`echo $line | sed 's/\[\(.*\)\]/\1/'`
     echo "Checking files for $OLD_SECTION "
     continue 
  fi

  # break on DIR  or we are still in header section declaration
  # The eval transform an ini line like 'CORE_DAYS=5' in a formal varaible assignement in script.
  # this is in fact the way we overload: Last come first serve, As you can see, come late pays, try this at job.
  eval $line
  word=`echo $line | cut -f1 -d=`

  if [ "$word" = "DIR" ];then
     if [ -n "$OLD_DIR" ];then
        do_job $ADMIN_DIR $OLD_DIR
        # if section default were defined, we need to restore after every execution
        # of a DIR line due to the possible overide
        if [ -n "$SECTION_FILE_DAYS" ];then
           FILE_DAYS=$SECTION_FILE_DAYS
        fi
        if [ -n "$SECTION_CORE_DAYS" ];then
           CORE_DAYS=$SECTION_CORE_DAYS
        fi
        if [ -n "$SECTION_EXT" ];then
           EXT=$SECTION_EXT
        fi
     fi
     OLD_DIR=$DIR
  fi
  # we are still between to section header and the first DIR line, so this is all default section
  if [ -z "$DIR" ];then
    if [ "$word" = "ADMIN_DIR" ];then
         :  # in all case only one exported per section
         export ADMIN_DIR
    elif [ "$word" = "CORE_DAYS" ];then
          SECTION_CORE_DAYS=`echo $line | cut -f2 -d=`
    elif [ "$word" = "FILE_DAYS" ];then
          SECTION_FILE_DAYS=`echo $line | cut -f2 -d=`
    elif [ "$word" = "EXT" ];then
          SECTION_EXT=` echo $line | cut -f2- -d=`
    elif [ "$word" = "FILE_CHECK" ];then
          FILE_CHECK=` echo $line | cut -f2- -d=`
    elif [ "$word" = "FILE_AGE" ];then
          FILE_AGE=` echo $line | cut -f2- -d=`
    else
      echo "Dunno what to do with this line : $line"   
    fi
  fi

done 
   # we are not in MS$, there is not control Z to signal the end of file which trigger the end of loop. 
   # The last DIR for which we gathered parameters must still be executed
   if [ -n $OLD_DIR ];then
      do_job $ADMIN_DIR $OLD_DIR
   fi
else
  echo "I Did not found $INIFILE, no panic, I am confidant you can find it"
fi
