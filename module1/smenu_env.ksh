#!/bin/sh
# set -xv
# SBIN=       # if not defined, defined it 
if [ "x-$SBIN" = "x-" ];then
   SBIN=/usr/local/smenu
fi
ENV_FILE=$SBIN/smenu.env
#rm $ENV_FILE
if [ ! -f $ENV_FILE ];then
   if [ `uname -a | awk '{print $1}'` = HP-UX ] ;then
       NAWK=/usr/bin/awk
   else
       type nawk
       if [ $? = 0 ];then
           NAWK=`type nawk | awk '{print$3}'`
       else
           NAWK=/usr/bin/awk
       fi
   fi
   HOST=`hostname`
   HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
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
S_USER=
HOST=$HOST
MAIL_PRG=mailx
MAIL_DEF_LIST=
GET_PASSWD=$SBINS/smenu_get_passwd
COMPRESS_PRG=compress
CRYPT_PASSWD=NO
TR=GENERIC

export SBIN S_USER NAWK SBINS HOST MAIL_PRG MAIL_DEF_LIST GET_PASSWD CRYPT_PASSWD TR
EOF

fi

cp $ENV_FILE ${ENV_FILE}.old

#----------------------------------------------------
modify_par()
{
#set -xv
var=$1 
mod=$2
  VAR1=${SBIN}
  VAR2=${SBINS}
  VAR3=${NAWK}
  VAR4=${S_USER}
  VAR5=${HOST}
  VAR6="${MAIL_PRG}"
  VAR7=${MAIL_DEF_LIST}
  VAR8=${GET_PASSWD}
  VAR9=${COMPRESS_PRG}
  VAR10=${CRYPT_PASSWD}
  VAR11=${TR}
  case $mod in
    1 )  VAR1=$var ;;
    2 )  VAR2=$var ;;
    3 )  VAR3=$var ;;
    4 )  VAR4=$var ;;
    5 )  VAR5=$var ;;
    6 )  VAR6="$var" ;;
    7 )  VAR7=$var ;;
    8 )  VAR8=$var ;;
    9 )  VAR9=$var ;;
    10 )  VAR10=$var ;;
    11 )  VAR11=$var ;;
   esac
SBIN=${VAR1}
SBINS=${VAR2}
NAWK=${VAR3}
S_USER=${VAR4}
HOST=${VAR5}
MAIL_PRG=${VAR6}
MAIL_DEF_LIST=${VAR7}
GET_PASSWD=${VAR8}
COMPRESS_PRG=${VAR9}
CRYPT_PASSWD=${VAR10}
TR=${VAR11}
               cat > $ENV_FILE <<EOF1
#----------------------------------------------------------------
# Update the following variables :
#
#       - $SBIN
#
# Optional : GET_PASSWD
# SBIN is the directory where you put smenu.sh.
SBIN=${VAR1}
SBINS=${VAR2}
NAWK=${VAR3}
S_USER=${VAR4}
HOST=${VAR5}
MAIL_PRG=${VAR6}
MAIL_DEF_LIST=${VAR7}
GET_PASSWD=${VAR8}
COMPRESS_PRG=${VAR9}
CRYPT_PASSWD=${VAR10}
TR=${VAR11}

export SBIN S_USER NAWK SBINS HOST MAIL_PRG MAIL_DEF_LIST GET_PASSWD COMPRESS_PRG

EOF1

}
#----------------------------------------------------
while true 
do
SBIN=`grep "^SBIN" $ENV_FILE | grep -v scripts| cut -f2 -d"="`
SBINS=`grep "^SBINS" $ENV_FILE | cut -f2 -d"="`
NAWK=`grep "^NAWK" $ENV_FILE | cut -f2 -d"="`
S_USER=`grep "^S_USER" $ENV_FILE | cut -f2 -d"="`
HOST=`grep "^HOST" $ENV_FILE | cut -f2 -d"="`
MAIL_PRG=`grep "^MAIL_PRG" $ENV_FILE | cut -f2 -d"="`
MAIL_DEF_LIST=`grep "^MAIL_DEF_LIST" $ENV_FILE | cut -f2 -d"="`
GET_PASSWD=`grep "^GET_PASSWD" $ENV_FILE | cut -f2 -d"="`
COMPRESS_PRG=`grep "^COMPRESS_PRG" $ENV_FILE | cut -f2 -d"="`
CRYPT_PASSWD=`grep "^CRYPT_PASSWD" $ENV_FILE | cut -f2 -d"="`
TR=`grep "^TR" $ENV_FILE | cut -f2 -d"="`

clear
cat <<EOF!


   *************************************************************
   *                                                           *
   *                   Modify SMENU settings                   *
   *                                                           *
   *************************************************************
       FILE  : $ENV_FILE

       
EOF!

echo
echo "     List of parameters SMENU"
echo "     ------------------------"
echo
echo "        1 ) SBIN           : $SBIN"
echo "        2 ) SBINS          : $SBINS"
echo "        3 ) NAWK           : $NAWK"
echo "        4 ) S_USER         : $S_USER"
echo "        5 ) HOST           : $HOST"
echo "        6 ) MAIL_PRG       : $MAIL_PRG"
echo "        7 ) MAIL_DEF_LIST  : $MAIL_DEF_LIST"
echo "        8 ) GET_PASSWD     : $GET_PASSWD"
echo "        9 ) COMPRESS       : $COMPRESS_PRG"
echo "        10) CRYPT_PASSWD   : $CRYPT_PASSWD"
echo "        11) TR             : $TR"
echo
echo " "
echo "    help ) h"
echo "    exit ) e        Undo ) u"
echo ' '
echo $NN ' Select a parameter to change ==> $NC'
read SEL
if [ "x-$SEL" = "x-e" ];then
    break
fi
if [ "x-$SEL" = "x-u" ];then
    cp ${ENV_FILE}.old ${ENV_FILE}
fi
if [ "x-$SEL" = "x-h" ];then
    vi $SBINS/smenu_env.help
fi
case $SEL in
     1 ) echo $NN "  New value for SBIN :==> $NC"
         read NEW_SBIN
             modify_par $NEW_SBIN 1 
         echo ;;
     2 ) echo $NN "  New value for SBINS :==> $NC"
         read NEW_SBINS
         modify_par ${NEW_SBINS} 2
         echo ;;
     3 ) echo $NN "  New value for NAWK :==> $NC"
         read NEW_NAWK
         modify_par ${NEW_NAWK} 3
         echo ;;
     4 ) echo $NN "  New value for S_USER :==> $NC"
         read S_USER
         modify_par ${S_USER} 4
         echo ;;
     5 ) echo $NN "  New value for HOST :==> $NC"
         read NEW_HOST
         modify_par ${NEW_HOST} 5
         echo ;;
     6 ) echo $NN "  New value for MAIL_PRG :==> $NC"
         read NEW_MAIL_PRG 
         modify_par "${NEW_MAIL_PRG}" 6
         echo ;;
     7 ) echo $NN "  New value for MAIL_LIST_DEF :==> $NC"
         read NEW_MAIL_LIST_DEF
         modify_par ${NEW_MAIL_LIST_DEF} 7
         echo ;;
     8 ) echo $NN "  New value for GET_PASSWD :==> $NC"
         read NEW_GET_PASSWD
         modify_par ${NEW_GET_PASSWD} 8
         echo ;;
     9 ) echo $NN "  New value for COMPRESS :==> $NC"
         read NEW_COMPRESS
         modify_par ${NEW_COMPRESS} 9
         echo ;;
     10 ) echo $NN "  New value for CRYPT_PASSWD :==> $NC"
         read NEW_CRYPT_PASSWD
         modify_par ${NEW_CRYPT_PASSWD} 10
         echo ;;
     11 ) echo $NN "  New value for TR [GENERIC or UCB]:==> $NC"
         read NEW_TR
         modify_par ${NEW_COMPRESS} 11
         echo ;;
esac
done
rm ${ENV_FILE}.old 
