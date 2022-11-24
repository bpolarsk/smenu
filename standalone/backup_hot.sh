#!/bin/sh
# this is a standalone backup script. to use it remove the exit
exit
#set -xv
# ----------------------------------------------------------------
# backup_hot.sh   : Online backup of Oracle database $ORACLE_SID.
#                 
# 13.07.1998 A.V. : Creation.
# 22.03.2000 BPL  : Add SERVICE for tivoli
#                   add Generic datafile, redologs list generation
#                   locate alert log, config from DB
#                   add detect Unix type
# 06.04.2000 BPL  : Add review section
#                    - detection of the oratab
#                    - detection of the oraenv
#                    - detection of the archive extent name (ARCFORMAT)
#                    - use of ORAENV_ASK
#                    - add use of optional TARGET_DIR 
# 29.10.2000 BPL  : Add compress option
# 30.10.2000 BPL  : Add detect compress method and compress dd
#                   Replace cpgz by an in line function
# 23.09.2005 BPL  : replaced svrmgrl by sqlplus '/ as sysdba'
# ---------------------------------------------------------------------
#

if [ "x-$1" = "x-" ];then
    cat <<EOF

          Usage : $0 ORACLE_SID [-z]

          Notes :   -z --> compress or gzip backup, depending on the detection :

                    if gzip is detected, then it is used
                    Otherwise compress is used

         if you do not compress, then cp is used.

EOF
    exit 1
fi

ORACLE_SID=$1
if [ "x-$2" = "x--z" ];then
      USE_COMPRESS=YES
      if [  -x /etc/mknod ];then
         MKNOD=/etc/mknod
      elif [ -x /usr/sbin/mknod ];then
           MKNOD=/usr/sbin/mknod
      else
           MKNOD=`which mknod`
      fi
      if [ ! -x $MKNOD ];then
         echo " Backup with compress required and no mknod found"
         echo "Aborting"
         exit 1
      fi
      COMPRESS_PRG=`which gzip`
      if [ -x $COMPRESS_PRG ];then
         Z_EXT=gz
      else
         Z_EXT=Z
         COMPRESS_PRG=compress
         CP=./unz.sh
      fi
else
      USE_COMPRESS=NO
      CP=cp
fi

# find oratab :
# -----------------------------------------------------------
# Detect Unix type to help tracking oratab
# -----------------------------------------------------------
UNIX=`uname -s`
if [ "x-$UNIX" = "x-AIX" ];then
        ORATAB_DIR=/etc
elif [ "x-$UNIX" = "x-OSF1" ];then
        ORATAB_DIR=/etc
elif [ "x-$UNIX" = "x-HP-UX" ];then
        ORATAB_DIR=/etc
elif [ "x-$UNIX" = "x-SunOS" ];then
        ORATAB_DIR=/var/opt/oracle
else
        ORATAB_DIR=/etc
fi
ORATAB=$ORATAB_DIR/oratab

if [ ! -f $ORATAB ];then
      echo "I do not know where is the oratab"
      exit 0
fi
# -----------------------------------------------------------
# find the oracle_home
# -----------------------------------------------------------
ORACLE_HOME=`grep "^${ORACLE_SID}:" $ORATAB | cut -f2 -d:`
if [ "x-$ORACLE_HOME"  = "x-" ];then
     echo "I can' t find the ORACLE_HOME"
     echo "Aborting backup process"
     exit 2
fi
# -----------------------------------------------------------
# find the oraenv :
# -----------------------------------------------------------
ORAENV=$ORACLE_HOME/bin/oraenv
if [ $? -eq 1 ];then
   if [ -f $ORACLE_HOME/bin/oraenv ];then
         ORAENV=$ORACLE_HOME/bin/oraenv
   elif [ -f /opt/bin/oracle/oraenv ];then
         ORAENV=/opt/bin/oracle/oraenv
   elif [ -f /usr/local/bin/oraenv ];then
         ORAENV=/usr/local/bin/oraenv
   elif [ -f $ORACLE_HOME/oraenv ];then
         ORAENV=$ORACLE_HOME/oraenv
   elif [ -f /etc/oraenv ];then
         ORAENV=/etc/oraenv
   else
         echo "I do not find the oraenv "
         exit 3
   fi
fi

# -----------------------------------------------------------
# --- Review these parameters at install time ---------------
# -----------------------------------------------------------


case $ORACLE_SID in

   "$ORACLE_SID" )
# ----- Option are : RAW or Filesystem. IF RAW selectec, then DD_BLOCK_SIZE may be
#                                       filled or left blank. ie : DD_BLOCK_SIZE="bs=512k"

BK_TYPE=Filesystem
DD_BLOCK_SIZE=

# ----- Number of days to keep (archives)
DAY_TO_KEEP=3

# ----- Number of days to keep audit file. Leave blank to ignore
AUDIT_TO_KEEP=1

# ----- selected as Backup dir
TARGET_BACK=

# ----- IF log_rchive_dest contains partial name of archive format
# ----- write here the dir name of archive direactory
ARC_DIR=

# ----- Log file for this process
LOG="$ORACLE_HOME/util/log/oralog${ORACLE_SID}"

      break ;;
           * ) echo "SID $ORACLE_SID is not defined in the customization of the backup"
           exit
esac

#------ optional security ----------------
if [ ! -d $TARGET_BACK ];then
      exit
fi
#-----------------------------------------

# -----------------------------------------------------------
# --- End review. From now on parameters are geners ---------
# -----------------------------------------------------------
# -----------------------------------------------------------
# -----------------------------------------------------------

ORAENV_ASK=NO
PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID ORACLE_HOME ORAENV_ASK PATH
. $ORAENV
ORAENV_ASK=YES
export ORAENV_ASK


BIN="$ORACLE_HOME/bin"
DATE_TODAY=`date +%Y%m%d`
PRODUCT=$ORACLE_SID
SERVICE=${PRODUCT}_${DATE_TODAY}


if [ -d $ORACLE_HOME/tmp ];then
      DIR_TMP=$ORACLE_HOME/tmp
else
      DIR_TMP=/tmp
fi


# --------- Working files -----------------------------------
DATAFILES="$DIR_TMP/datafile_$ORACLE_SID.lst"
REDOLOGS="$DIR_TMP/redologs_$ORACLE_SID.lst"
CONTROLFILE="$DIR_TMP/controlfile_$ORACLE_SID.lst"
PFILE="$DIR_TMP/pfile_$ORACLE_SID.lst"
TRACE_DIR="$DIR_TMP/trace_dir_$ORACLE_SID.lst"
ARCHLOGS="$DIR_TMP/archlog_$ORACLE_SID.dir"
ARCHFORMAT="$DIR_TMP/archformat_$ORACLE_SID.dir"
ALERTLOG="$DIR_TMP/alertlog_$ORACLE_SID.file"
TMP_FILE="$DIR_TMP/tmp_file_$ORACLE_SID.tmp"

# -----------------------------------------------------------
mk_unzip_fun() 
{
if [  $USE_COMPRESS = 'NO' ]; then
   if [  $BK_TYPE = 'RAW' ]; then
       #
       # ************ Raw Devices ************
       #
       cat > $RESTORE <<EOF
#!/bin/sh
# restore.sh
# generated by backup_file.sh the $DATE

   if [  -f unz.sh ];then
         rm unz.sh
   fi
   > unz.sh
   echo "#!/bin/sh                       "    >> unz.sh
   echo "set -xv                              "    >> unz.sh
   echo "dd if=\\\$1 of=\\\$2  $DD_BLOCK_SIZE "    >> unz.sh
CP=./unz.sh                             
chmod 755 ./unz.sh
#
# Put this in comment if you want to run this script
#
#-----------------
exit
#-----------------
#
EOF

      else    # USE_COMPRESS=NO, RAW


       #
       # ************ Filesystem  ************
       #
       cat > $RESTORE <<EOF
#!/bin/sh
# restore.sh
# generated by backup_file.sh the $DATE

CP=cp
SID=$ORACLE_SID

#
# Put this in comment if you want to run this script
#
#-----------------
exit
#-----------------
#
EOF
      fi
else  # we are using compressing 
   if [  $BK_TYPE = 'RAW' ]; then
       #
       # ************ Raw Devices ************
       #
       cat > $RESTORE <<EOF
#!/bin/sh
# restore.sh
# generated by backup_file.sh the $DATE
# we are using zcat for compressed file, use gzcat for gzip files

if [  -f unz.sh ];then
   rm unz.sh
fi
   > unz.sh
   echo "#!/bin/sh                            "    >> unz.sh
   echo "set -xv                              "    >> unz.sh
   echo " if [ -f /tmp/my_pipe\\\$\\\$ ];then "    >> unz.sh
   echo "    rm  /tmp/my_pipe\\\$\\\$         "    >> unz.sh
   echo " fi                                  "    >> unz.sh
   echo " $MKNOD /tmp/my_pipe\\\$\\\$ p       "    >> unz.sh
   echo "# as we do not know if zcat as gzip capabilities ..."
   if [ "x-$Z_EXT" = "x-gz" ];then
      echo " cat \\\$1.$Z_EXT  | gzip -d > /tmp/my_pipe\\\$\\\$ & " >> unz.sh
   else
      echo " zcat \\\$1.$Z_EXT > /tmp/my_pipe\\\$\\\$ & " >> unz.sh
   fi
   echo "dd if=/tmp/my_pipe\\\$\\\$ of=\\\$2  $DD_BLOCK_SIZE    " >> unz.sh
   echo "rm /tmp/my_pipe\\\$\\\$              "    >> unz.sh
CP=./unz.sh                             
chmod 755 ./unz.sh
#
# Put this in comment if you want to run this script
#
#-----------------
exit
#-----------------
#
EOF

     else   # USE_COMPRESS=YES, RAW


       #
       # ************ Filesystem  ************
       #
       cat > $RESTORE <<EOF
#!/bin/sh
# restore.sh
# generated by backup_file.sh the $DATE
# we are using zcat for compressed file, use gzcat for gzip files

if [  -f unz.sh ];then
   rm unz.sh
fi
   > unz.sh
   echo "#!/bin/sh                            "    >> unz.sh
   echo "set -xv                              "    >> unz.sh
   echo " if [ -f /tmp/my_pipe\\\$\\\$ ];then "    >> unz.sh
   echo "    rm  /tmp/my_pipe\\\$\\\$         "    >> unz.sh
   echo " fi                                  "    >> unz.sh
   echo " $MKNOD /tmp/my_pipe\\\$\\\$ p   "    >> unz.sh
   echo "# as we do not know if zcat as gzip capabilities ..."
   if [ "x-$Z_EXT" = "x-gz" ];then
      echo " cat \\\$1.$Z_EXT  | gzip -d > /tmp/my_pipe\\\$\\\$ & " >> unz.sh
   else
      echo " zcat \\\$1.$Z_EXT > /tmp/my_pipe\\\$\\\$ & " >> unz.sh
   fi
   echo " cat /tmp/my_pipe\\\$\\\$ > \\\$2       "    >> unz.sh
   echo " rm /tmp/my_pipe\\\$\\\$             "    >> unz.sh
   chmod 755 ./unz.sh

CP=./unz.sh
SID=$ORACLE_SID

#
# Put this in comment if you want to run this script
#
#-----------------
exit
#-----------------
#
EOF

    fi  # RAW/Filesystem
fi      # USE_COMPRESS=NO/YES

}

# -----------------------------------------------------------
p_log()
{
echo $* >> $LOG
}
# -----------------------------------------------------------

# -----------------------------------------------------------
# p_logd : print in log file with date
# -----------------------------------------------------------
p_logd()
{
d=`date '+[%d/%m/%y %H:%M:%S]`
echo "$d $*"  >> $LOG
}
# -----------------------------------------------------------

copyf()
{
    SOURCE=$1
    TARGET=$2

    if [ "x-$1" = "x-" ];then
       p_log "Missing first argument in copyf"
    fi
    if [ "x-$2" = "x-" ];then
       p_log "Missing second argument in copyf"
    fi
       
    if [ $BK_TYPE = Filesystem ];then 
       p_log "cp $SOURCE $TARGET"
       if [ ! -f $SOURCE ];then
          p_log "BACK-003 : Source file does not exists ! "
          return
       fi
       if [ "x-$USE_COMPRESS" = "x-NO" ];then
            echo "\$CP $TARGET $SOURCE" >> $RESTORE
            cp $SOURCE $TARGET >> $LOG 2>&1
            STATUS=$?
       else
               echo "\$CP $TARGET $SOURCE" >> $RESTORE
               PIPE=/tmp/backup_fifo
               if [ -p $PIPE ];then
                  rm $PIPE
               fi
               $MKNOD $PIPE p
               TARGET_Z=${TARGET}.$Z_EXT
               cat $PIPE | $COMPRESS_PRG > $TARGET_Z &
               cp $SOURCE $PIPE >> $LOG 2>&1
               STATUS=$?
               rm $PIPE
       fi
       if [ "$STATUS" != 0 ]; then
         p_log  "BACK-001 : Error during file copy $FILE "
       fi
    elif [ $BK_TYPE = RAW ];then
          p_log "   dd if=$SOURCE of=$TARGET $DD_BLOCK_SIZE"
          if [ "x-$USE_COMPRESS" = "x-NO" ];then
               dd if=$SOURCE of=$TARGET $DD_BLOCK_SIZE
               STATUS=$?
               echo "\$CP $SOURCE $TARGET "
               echo "\$CP $TARGET $SOURCE" >> $RESTORE
          else
               # compress for dd files is required :
               PIPE=/tmp/backup_fifo
               if [ -p $PIPE ];then
                  rm $PIPE
               fi
               $MKNOD $PIPE p
               TARGET_Z=${TARGET}.$Z_EXT
               cat $PIPE | $COMPRESS_PRG > $TARGET_Z &
               dd if=$SOURCE of=$PIPE $DD_BLOCK_SIZE
               STATUS=$?
               rm $PIPE
               echo "\$CP $TARGET $SOURCE " >> $RESTORE
          fi
          if [ ! $STATUS -eq 0 ]; then
               p_log  "BACK-005 : Error during dd of $FILE "
               echo "#--ERROR--check!#dd if=$TARGET of=$SOURCE $DD_BLOCK_SIZE" >> $RESTORE
          fi
    fi 
}
# -----------------------------------------------------------
# Start process : fill working files
# -----------------------------------------------------------
p_log " "
p_log " "
p_log "START-$SERVICE"
p_log " "
p_log " "
p_log "-------- Begin of online backup --------" 

p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Extract data from DB to fill work files"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
# *******************************************************************************************
# ******** for pre-Oracle 8i take this line in place of the union ***************************
#select file_name,tablespace_name from sys.dba_data_files order by tablespace_name,file_name;
# *******************************************************************************************
$BIN/sqlplus '/ as sysdba'  <<EOF >> $LOG 2>&1
spool $DATAFILES;
select file_name,tablespace_name from sys.dba_data_files order by tablespace_name,file_name
union
select a.name file_name, b.name tablespace_name from v\$tempfile a, ts$ b where a.ts# = b.ts#
spool off;
spool $REDOLOGS;
select member name from v\$logfile;
spool off;
spool $CONTROLFILE;
select name name from v\$controlfile;
spool off;
spool $ARCHLOGS;
select value from v\$parameter where name like 'log_archive_dest%' and
name not like 'log_archive_dest_s%' and value is not null and rownum=1 ;
spool off;
spool $ARCHFORMAT;
select value from v\$parameter where name='log_archive_format';
spool off;
spool $ALERTLOG;
select value from v\$parameter where name='background_dump_dest';
spool off;
spool $PFILE
select value from v\$parameter where name='ifile';
spool off;
spool $TRACE_DIR;
select value from v\$parameter where name='user_dump_dest';
spool off;
exit
EOF

# --------------------------------------------------------------
# Remove old archivelogs and trace files
# Extract and fill variable $BU
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Remove old archive logs older than $DAY_TO_KEEP days"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
#
# --------------------------------------------------------------
# if ARC_DIR was not declare, then take it from DB
# --------------------------------------------------------------
#
if [ "x-$ARC_DIR" = "x-" ];then
      ARC_DIR=`sed -e 's/[    ]*$//' -e '/selected\.$/d'  -e '/^---.*--$/d'  -e '/^VALUE/d' $ARCHLOGS`
      echo $ARC_DIR | grep '=' >/dev/null
      if [ $? = 0 ];then
         ARC_DIR=`echo $ARC_DIR | cut -f2 -d=`
      fi
fi
VAR=`sed -e 's/[    ]*$//' -e '/selected\.$/d'  -e '/^---.*--$/d'  -e '/^VALUE/d' $ARCHFORMAT`
ARC_EXT=`echo $VAR | cut -f2 -d'.'`

if [ "x-$TARGET_BACK" = "x-" ];then
      BU=$ARC_DIR
else
      BU=$TARGET_BACK
fi


if [ "x-$BU" = "x-" ];then
   p_log "BACK-004  : BU Dir not defined " 
   exit 1
elif [ ! -d $BU ];then
   p_log "BACK-004  : BU Dir does not exists"
   exit 1
fi
export BU

RESTORE=${BU}/restore_hot_${ORACLE_SID}.sh
echo "# Restore script of hot backup : `date`"> $RESTORE
echo " "         >> $RESTORE
echo "exit"      >> $RESTORE
echo " "         >> $RESTORE
mk_unzip_fun

if [ "x-$ARC_DIR" = "x-" ];then
   p_log "BACK-002 : Cannot determine the archive Directory"
else
   if [ -d $ARC_DIR ];then
        p_log "Archive directory : $ARC_DIR" 
        if [ ! "x-$ARC_EXT" = "x-" ];then
           p_log " "
           p_log " The following archive are purged because they are older than $DAY_TO_KEEP days."
           find "$ARC_DIR" -name "*.$ARC_EXT" -mtime +$DAY_TO_KEEP -exec ls {} \; >>$LOG 2>&1
           find "$ARC_DIR" -name "*.$ARC_EXT" -mtime +$DAY_TO_KEEP -exec rm {} \; >>$LOG 2>&1
        fi
   else
       p_log "ARC_DIR : $ARC_DIR does not exists " 
   fi
   rm $BU/*.trc                                         >>$LOG 2>&1
fi

# --------------------------------------------------------------
# Mark all tablespaces for begin of backup
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Mark all tablespaces in begin backup mode"
p_log " --------------------------------------------------------------"
p_log " "


  OLD=NO_TBS
  SED="sed -e '/selected\.$/d' -e '/^---.*--$/d'  -e '/^FILE_NAME/d' $DATAFILES"

  eval $SED | while read FILE TABLESPACE
  do
    if [ "x-$TABLESPACE" != "x-$OLD" ];then
       p_log " "
       p_log " ### Setting $TABLESPACE in begin backup mode ### "
       $BIN/sqlplus '/ as sysdba' <<EOF >> $LOG 2>&1
       alter tablespace "$TABLESPACE" begin backup;
       exit
EOF
   fi
   OLD=$TABLESPACE
  done


# --------------------------------------------------------------
# cp all database files : 
# Clear datafiles from previous backup then
# start copy. But if datafile alerady exits
# to track return code and choose between copy method :
# cp or dd. We may also add gzipped copy in copy (TBD)
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Starting the copy of the DBF files "
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
  echo "#------------ Datafiles -----------------------" >> $RESTORE
  eval $SED | while read FILE TABLESPACE
  do
    DATAFILE=`basename $FILE`
    copyf $FILE $BU/$DATAFILE
  done

# --------------------------------------------------------------
# Mark all tablespaces for end backup mode
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Mark all tablespaces for end backup mode"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "


  OLD=NO_TBS
  SED="sed -e '/selected\.$/d' -e '/^---.*--$/d'  -e '/^FILE_NAME/d' $DATAFILES"

  eval $SED | while read FILE TABLESPACE
  do
    if [ "x-$TABLESPACE" != "x-$OLD" ];then
       p_log " ### Setting $TABLESPACE in end backup mode ###"
       $BIN/sqlplus '/ as sysdba' <<EOF >> $LOG 2>&1
       alter tablespace "$TABLESPACE" end backup;
       exit
EOF
    fi
    OLD=$TABLESPACE
  done

# --------------------------------------------------------------
# Switch logfile and archive logs
# --------------------------------------------------------------

p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Switch log redologs after backup"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "

$BIN/sqlplus '/ as sysdba' <<EOF >>$LOG 2>&1
alter system archive log all;
alter system switch logfile;
exit ;
EOF

# --------------------------------------------------------------
# Copy Redologs : no necessary for hot backup, but we will place 
# them in their normal place and open the DB in open resetlogs,
# saving the create control file commands. (old trick)
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Optional copy of redologs"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
echo "#------------ Redologs  -----------------------" >> $RESTORE
sed -e '/selected\.$/d' -e '/^---.*--$/d' -e '/^NAME/d' $REDOLOGS | while read FILE
   do
      FILE_SHORT=`basename $FILE`
      copyf $FILE $BU/$FILE_SHORT
done


# --------------------------------------------------------------
# We copy nothing here but prepare the restore
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Writing placement of controlfiles for restore.sh"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
echo "#------------ Controlfiles --------------------" >> $RESTORE
sed -e '/selected\.$/d' -e '/^---.*--$/d' -e '/^NAME/d' $CONTROLFILE | while read FILE
   do
      FILE_SHORT=`basename $FILE`
      if [ $BK_TYPE = RAW ];then
          if [ "x-$USE_COMPRESS" = "x-NO" ];then
               p_log "\$CP $$BU/bu_ctl${ORACLE_SID}.ctl $FILE"
               echo "\$CP $BU/bu_ctl${ORACLE_SID}.ctl $FILE" >> $RESTORE
          else
               echo "\$CP $BU/bu_ctl${ORACLE_SID}.ctl $FILE" >> $RESTORE
               p_log "$CP if=$BU/bu_ctl${ORACLE_SID}.ctl of=$FILE"
          fi
      else
           echo "\$CP $BU/bu_ctl${ORACLE_SID}.ctl $FILE" >> $RESTORE
           p_log "cp $BU/bu_ctl${ORACLE_SID}.ctl $FILE"
      fi
done



echo "#------------ Pfiles --------------------------" >> $RESTORE
# --------------------------------------------------------------
# Copy Pfiles
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Check for existence of config.ora  "
p_log " --------------------------------------------------------------"
p_log " "
p_log " "
sed -e '/selected\.$/d' -e '/^---.*--$/d' -e '/^VALUE/d' $PFILE | while read FILE
   do
      if [ ! "x-$FILE" = "x-" ];then
         PFILE_SHORT=`basename $FILE`
         cp $FILE $BU/$PFILE_SHORT
         echo "\$CP $BU/$PFILE_SHORT $FILE" >> $RESTORE
         p_log "cp $BU/$PFILE_SHORT $FILE"
      else
         p_log "No config.ora file"
      fi
done

p_log " "
# --------------------------------------------------------------
# Do not user the copyf function here, as it may be a dd
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Copy init.ora, listerner, tnsnames and sqlnet.ora "
p_log " --------------------------------------------------------------"
p_log " "
p_log " "


p_log "$ORACLE_HOME/dbs/init$ORACLE_SID.ora $BU"
cp ${ORACLE_HOME}/dbs/init$ORACLE_SID.ora   $BU >> $LOG 2>&1
echo "#cp $BU/init$ORACLE_SID.ora ${ORACLE_HOME}/dbs/init$ORACLE_SID.ora" >> $RESTORE

p_log "cp $ORACLE_HOME/network/admin/listener.ora $BU"
cp ${ORACLE_HOME}/network/admin/listener.ora     $BU  >> $LOG 2>&1
echo "#cp $BU/listener.ora  ${ORACLE_HOME}/network/admin/listener.ora" >> $RESTORE

p_log "cp $ORACLE_HOME/network/admin/tnsnames.ora $BU"
cp ${ORACLE_HOME}/network/admin/tnsnames.ora     $BU >> $LOG 2>&1
echo "#cp $BU tnsnames.ora ${ORACLE_HOME}/network/admin/tnsnames.ora" >> $RESTORE

p_log "cp $ORACLE_HOME/network/admin/sqlnet.ora $BU"
cp ${ORACLE_HOME}/network/admin/sqlnet.ora     $BU >> $LOG 2>&1
echo "#cp $BU/sqlnet.ora ${ORACLE_HOME}/network/admin/sqlnet.ora" >> $RESTORE


# --------------------------------------------------------------
# Backup controlfile
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Backup control file and produce a backup control file to trace"
p_log " --------------------------------------------------------------"
p_log " "
p_log " "

$BIN/sqlplus '/ as sysdba' <<EOF >> $LOG 2>&1
alter database backup controlfile to '$BU/bu_ctl${ORACLE_SID}.ctl' reuse;
alter database backup controlfile to trace noresetlogs;
exit
EOF
$COMPRESS_PRG $BU/bu_ctl${ORACLE_SID}.ctl

p_log "alter database backup controlfile to '$BU/bu_ctl${ORACLE_SID}.ctl' reuse;"
p_log "alter database backup controlfile to trace noresetlogs;"
# --------------------------------------------------------------
# Copying the backup to trace
# --------------------------------------------------------------
p_log " "
p_log " "
p_log " --------------------------------------------------------------"
p_log " Copying the backup to trace                                  "
p_log " --------------------------------------------------------------"
USER_DUMP_DIR=`sed -e 's/[    ]*$//' -e '/selected\.$/d'  -e '/^---.*--$/d'  -e '/^VALUE/d' $TRACE_DIR`
if [ ! "x-$USER_DUMP_DIR" = "x-" ];then
   if [ -d $USER_DUMP_DIR ];then
        cd $USER_DUMP_DIR
        LAST_TRC=`ls -t ./*.trc | head -1`
        cp $LAST_TRC $BU
   fi
fi

# --------------------------------------------------------------
# --------------------------------------------------------------
# --------------------------------------------------------------

p_log " "
p_log " "
p_log " "
p_log "------- End of online backup ------- "
p_log " "
p_log " "

# backup finished
p_log "### `date` ### END ONLINE BACKUP - database $ORACLE_HOME $ORACLE_HOME$ORACLE_HOME  ####"
p_log "STOP-$SERVICE" 

