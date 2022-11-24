#!/usr/bin/ksh
# Author : Polarski bernard
# Date   : 1998
#set -xv
trap 'if [ -f /tmp/zzgg_t.sql ];then
          rm /tmp/zzgg_t.sql
      fi 
      exit ' 0 2 9 13 15 
# In order to make sure that the trace file is readable by any user 
# (owned by oracle with group id DBA), set the init.ora parameter
# '_trace_files_public=true '

SBINS=${SBIN}/scripts
cd $SBINS

if [ -n "$1" ];then
   MAX="| head -$1"
   LIMIT="  Limit to number of .trc file to list is set to $1"
else
  LIMIT="  Type 'tkp n' to limit the .trc list to the first n files"
  unset MAX
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
FOUT=/tmp/zzgg_1.sql

> $FOUT
echo "Retrieveing User demp dest : \c"
a=`
sqlplus -s "$CONNECT_STRING" <<EOF1 
set head off
select value from V\\$parameter where name = 'user_dump_dest';
EOF1
`
UDUMP=`echo $a |awk '{print $1}'`
echo " got it ! \n====> $UDUMP"
if [ ! -d $UDUMP ];then
   echo "Alert : $UDUMP does not exist --> aborting "
   exit 1
else
   echo "Changing path to user_dump_dest directories"
fi
cd $UDUMP

eval ls -lt *.trc $MAX> $FOUT

X_EXPL=NO
X_SYS=NO
X_AGG=NO
OPT_EXPL=YES
OPT_SYS=YES
OPT_AGG=YES
while true 
do
echo " "
echo " *********************************************************************"
echo "  $LIMIT "
echo "    Tkprof parameters :     -Explain plan  : $X_EXPL "
echo "                            -Aggregate     : $X_AGG"
echo "                            -Sys           : $X_SYS "
echo " "
echo "    Append a 'v' to the number, if you want only see the trc file "
echo " *********************************************************************"
echo " "
echo " Trace file to process :"
echo " "
cpt=1
while read a
  do
  echo " $cpt : $a "
  cpt=`expr $cpt + 1`
done<$FOUT
echo 
echo 
echo " p   : explain plan ==> $OPT_EXPL"
echo " a   : Aggregate    ==> $OPT_AGG"
echo " s   : SYS          ==> $OPT_SYS"
echo " "
echo " e   : exit"
echo " "
echo " Select a trace file to process  ==> \c"
read fil_trc_num
if [ "x-$fil_trc_num" = "x-e" ];then
   exit
else
   if [ "x-$fil_trc_num" = "x-a" ];then
      X_AGG=$OPT_AGG
      if [ $OPT_AGG = NO ];then
         OPT_AGG=YES
      else
         OPT_AGG=NO
      fi
      continue
   fi
   if [ "x-$fil_trc_num" = "x-p" ];then
      X_EXPL=$OPT_EXPL
      if [ $OPT_EXPL = NO ];then
         OPT_EXPL=YES
      else
         OPT_EXPL=NO
      fi
      continue
   fi
   if [ "x-$fil_trc_num" = "x-s" ];then
      X_SYS=$OPT_SYS
      if [ $OPT_SYS = NO ];then
         OPT_SYS=YES
      else
         OPT_SYS=NO
      fi
      continue
   fi
   var=`echo $fil_trc_num | grep 'v'`
   if [ $? -eq 0 ];then
     fil_trc_num=`echo $fil_trc_num | sed 's/v//'`
     LIGN=`head -$fil_trc_num $FOUT | tail -1`
     FILE_TO_VIEW=`echo $LIGN | awk '{print $9}'`
     view $FILE_TO_VIEW
   else
     fil_trc_num=`echo $fil_trc_num | sed 's/n//'`
     LIGN=`head -$fil_trc_num $FOUT | tail -1`
     FILE_TO_TRACE=`echo $LIGN | awk '{print $9}'`
     FILE_OUT=`echo $FILE_TO_TRACE | sed 's/trc/txt/g'`
     PARAM=""
     if [ $X_EXPL = YES ];then
	  if $SBINS/yesno.sh " to use default user [$CONNECT_STRING] " DO Y
	      then
              PARAM=explain=$CONNECT_STRING
	  else
	      echo " Input the User name and its password in the form : \"USER/PASSWD\""
	      echo "===> \c"
	      read USRPASSWD
              PARAM=explain=$CONNECT_STRING
          fi
     fi
     if [ $X_SYS = YES ];then
        PARAM=$PARAM" "SYS=$X_SYS
     fi
     if [ $X_AGG = YES ];then
        PARAM=$PARAM" "aggregate=$X_AGG
     fi
     if $SBINS/yesno.sh " to run tkprof  on $FILE_TO_TRACE "
        then
        echo "doing : tkprof $FILE_TO_TRACE $FILE_OUT $PARAM"
        tkprof $FILE_TO_TRACE $FILE_OUT $PARAM
        vi $FILE_OUT
        if $SBINS/yesno.sh "keep the ouptut file [n] " DO
           then
           echo " Ok, I keep it in udump DIR."
        else
                  rm $FILE_OUT
        fi
     else
        echo "Next time may be, life is so unpredictable ....."
     fi
   fi
fi
done
