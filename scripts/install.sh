#!/usr/bin/ksh
# install.sh 
# set -x
SBIN=`pwd`/smenu
UNAME=`uname| awk '{print $1}'`
NAWK=`whence nawk`
if [ ! -x "$NAWK" ];then
   unset NAWK
fi
case $UNAME in
        # 2006-03-11  Jan Vermue  When using Cygwin, correctly convert SBIN to use DOS drive letters
  CYG*) case $SBIN in
          ?cygdrive???*) SBIN=`echo $SBIN|sed -e "s;/cygdrive/;;" -e "s;/;:/;"`;;
            *) ROOTDIR=`grep chdir /cygwin.bat | sed -e 's/chdir //' -e 's/\\\\bin.*$//' -e 's;\\\\;/;g'`
               SBIN=$ROOTDIR$SBIN;;
        esac
        NAWK=/usr/bin/awk 
        # add now customized version of oraenv and dbhome
        if [ -d /usr/local/bin ];then
           for i in oraenv dbhome
           do
               if [ ! -f /usr/local/bin/$i ];then
                  cp -p smenu/scripts/$i.cyg /usr/local/bin/$i
                  chmod 755  /usr/local/bin/$i
               fi
           done

           if [ ! -f /etc/oratab ];then
              if [ -d /etc ];then
                 ORACLE_SID=${ORACLE_SID:-ORCL}
                 ORACLE_HOME=${ORACLE_HOME:-*}
                 echo "$ORACLE_SID:*:Y" > /etc/oratab
              else
                 echo "I need a directory /etc"
                 exit
              fi
           fi   
        else
          echo "No /usr/local/bin directory; I need one to place a copy of oraenv and dbhome specific for Cygwin"
        fi   
        NN=-N
        unset NC
        ;;
  HP-UX  )  NAWK=${NAWK:-/usr/bin/nawk}
            NC='\c' 
            unset NN;;
    AIX  )  NAWK=${NAWK:-/usr/bin/nawk}
            NC='\c'
            unset NN;;
  SunOS  )  NAWK=${NAWK:-/usr/bin/awk}
            NC='\C'
            unset NN;;
  Linux  )  NAWK=${NAWK:-/bin/awk}
            NN=-n
            unset NC
            ;;
     *   )  unset NN
            NC='\c'
       type nawk 2>/dev/null
       if [ $? = 0 ];then
           NAWK=`type nawk | awk '{print$3}'`
       else
           NAWK=/usr/bin/awk
       fi;;
esac

echo SBIN=$SBIN
ENV_FILE=$SBIN/smenu.env

int1() {

     FUS=$1
     echo "   You may input the password of $FUS "
     echo "   If smenu does not have a password, it "
     echo "   will ask one every time you run a query. "
     echo "   However, you may input one later by going "
     echo "   to menu 1 option 3. (SM/1.3) "
     echo "   "
     echo "   "
     if $SBIN/scripts/yesno.sh "to input a password for $FUS" DO Y
        then
           echo $NN " Password  : $NC"
           stty -echo
           read fts
           stty echo
           echo " "
           echo " "
           if [ "x-ORACLE_SID" = "x-" ];then
              echo "Oracle SID is not defined for $FUS."
              echo $NN "Oracle SID ==> $NC "
              read SID
           elif $SBIN/scripts/yesno.sh "to use $ORACLE_SID as SID" DO Y
               then
                SID=$ORACLE_SID 
           else
                  echo $NN "Oracle SID ==> $NC "
                  read SID
           fi
           echo "$SID:$FUS:$fts" >> $SBIN/scripts/.passwd
     else
           echo " "
           echo "     Ok : I will ask you for a passwd at each query."
           echo "     If you change your mind, go to the menu 1 option "
           echo "     (SM/1.5) "
           echo " "
           if [ "x-ORACLE_SID" = "x-" ];then
              echo "Oracle SID is not defined for $FUS."
              echo $NN "Oracle SID ==> $NC "
              read SID
           elif $SBIN/scripts/yesno.sh "to use $ORACLE_SID as SID" DO Y
               then
                SID=$ORACLE_SID 
           else
                  echo $NN "Oracle SID ==> $NC "
                  read SID
           fi
           if [ "x-$SID" = "x-" ];then
              echo "No SID ==> Skippiong user definition !"
           else
              echo "$SID:$FUS:" >> $SBIN/scripts/.passwd
           fi
     fi
}
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
VERSION=`cat $SBIN/scripts/version.txt`
COMPRESS=gzip  # change this here or in SM/1.1
BOL=TRUE
if $SBIN/scripts/yesno.sh " your default user to be SYS " DO Y
   then
     DEFAULT_U=SYS
     int1 $DEFAULT_U
else
   echo "     I need a default user name for smenu."
   echo "     This user should have the grat DBA."
   echo " "
   echo $NN  "     Default user ==> $NC"
   read DEFAULT_U
   if [ "x-$DEFAULT_U" = "x-" ];then
      echo " "
      echo "     Ok : I will ask you for a user/passwd at each query."
      echo "     If you change your mind, go to the menu 1 option "
      echo "     (SM/1.5) "
      echo " "
   else
      int1 $DEFAULT_U
  fi
  if $SBIN/scripts/yesno.sh " Use local oarenv" DO Y
  then
    BOL=TRUE
  else
    BOL=FALSE
  fi
fi
PLATFORM=`uname`
if [ "$PLATFORM" = "SunOS" ];then
   TR=UCB
else
   TR=USUAL
fi
echo SBIN=$SBIN
chmod 777 $SBIN/tmp   # case of, it is mandatory for cygwin when you run sampler
                      # As the writing in sampler is an Oracle owner process
                      # (utl_file pkg) and you launched the process as yourself
                      # Thanks to Jan vermulen to point that!
   cat > $ENV_FILE <<EOF
#----------------------------------------------------------------
# Update the following variables :
#
#       - $SBIN
#
# Optional : GET_PASSWD
# SBIN is the directory where you put smenu.sh.
SBIN=$SBIN
SBINS=$SBIN/scripts
NAWK=$NAWK
S_USER=$DEFAULT_U
S_SYS_REMOTE=$BOL
HOST=$HOST
GET_PASSWD=$SBIN/scripts/smenu_get_passwd
VERSION=$VERSION
COMPRESS=$COMPRESS
TR=$TR
NN=$NN
NC=$NC

export SBIN S_USER NAWK SBINS HOST MAIL_PRG MAIL_DEF_LIST GET_PASSWD COMPRESS S_SYS_REMOTE NN NC
EOF

ADDPAR=./smenu/scripts/addpar.sh
if [ -f $ADDPAR ];then
   rm $ADDPAR
fi
cat >  $ADDPAR <<EOF3
# For all Stackanovitch of the Keystroke, here is your relief:
# Add some variables to the current shell : BPA 15/06/99
set -o vi

NAWK=$NAWK
export NAWK
# --------- Variables==> ex : "cp file $ai" ------
SBIN=$SBIN  
EOF3

cat ./addpar.tail >> $ADDPAR
cd ./smenu
if [ -f ad ];then
   rm ./ad
   ln -s ./scripts/addpar.sh ad
fi
clear
cat <<EOF




      Installation customized !

      To launch Smenu, type :

        if your . is in your path
        --------------------------

            cd smenu
            . ad
            sm        (if you are in ksh)
            or
            smenu.sh  (if you are in sh )


            if your . is not in your path
            -----------------------------

            cd ./smenu
            . ./ad
            ./sm   (if you are in ksh)
            or
            smenu.sh  (if you are in sh )


    After smenu us loaded, type 'sp' to view all commands.
EOF
