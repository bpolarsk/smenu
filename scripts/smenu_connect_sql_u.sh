#!/usr/bin/ksh 
#set -xv
# smenu_change_S_USER.sh

FILE=$SBIN/scripts/.passwd

echo " "
      if [[ -n ${S_USER} ]]; then
         export S_USER
         banner "$S_USER"
         . $SBIN/scripts/passwd.env
         . ${GET_PASSWD} 
         if [  "x-$PASSWD" = "x-" ];then
            echo "could no get the password of $S_USER"
            break 
         fi
         banner "$ORACLE_SID"
         sqlplus $S_USER/$PASSWD
      else
         print -u2 "Invalid choice"
      fi

