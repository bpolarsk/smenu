#!/usr/bin/ksh -xv
#set -xv
# smenu_change_S_USER.sh

FILE=$SBIN/scripts/.passwd

echo " "
PS3=' Select SID ==> '
#S_USERLIST=`cat $FILE | awk -F: '/^[^#^\*]/ { printf "%s ", $2 }  ' | sort -u`
S_USERLIST=`cat $FILE | cut -f2 -d: | sort -u`
echo "\n User :\n\n"
select S_USER in ${S_USERLIST}
   do
      if [[ -n ${S_USER} ]]; then
         S_USER=`echo $S_USER| $NAWK '{print toupper($1) }'`
         export S_USER
echo "S_USER=$S_USER"
         banner $S_USER
         break
      else
         print -u2 "Invalid choice"
      fi
done

