#!/bin/ksh
# set -x
# smenu_change_S_USER.sh


FILE=$SBIN/scripts/.passwd
echo " "
PS3=' Select SID ==> '
# overlaod S_USER for DAS
if [ -n "${DAS}" ];then 
   S_USERLIST=$ORACLE_SID:$DAS
else
   S_USERLIST=`cat $FILE | cut -f1-2 -d: | sort -u`
fi
echo " User : "
select SID_USER in ${S_USERLIST}
   do
      if [[ -n ${SID_USER} ]]; then
         S_USER=`echo $SID_USER | cut -f2 -d:`
         VAR=`who am i | awk '{print $1}'`
         # this is unixies case insensitive comparison in SHELL
         ret=`echo ${S_USER} | grep -i $VAR`
         if [ $? -eq 0 ];then 
            if [  -n "$DAS" ];then
              # redefine the smenu_ key to current sid
              export SMENU_KEY=${PWA}@$ORACLE_SID
              CONNECT_STRING="$DAS/$SMENU_KEY"
              type banner > /dev/null 2>&1
              if [ $? -eq 0 ];then
                 banner $S_USER
                 banner $ORACLE_SID
              fi
              sqlplus -L  "$CONNECT_STRING"
            fi
         else
            SID=`echo $SID_USER | cut -f1 -d:`
            ORACLE_SID=$SID
            export S_USER 
            if [ -f $SBINS/.prod ] ;then
               grep -q "^${ORACLE_SID}|" $SBINS/.prod
               ret=$?
               if [ $ret -eq 0 ];then
                  BGRED=TRUE
                  echo "\033[41m"
               fi
            fi
            type banner > /dev/null 2>&1
            if [ $? -eq 0 ];then
               banner $S_USER
               banner $ORACLE_SID
            fi
            . $SBIN/scripts/passwd.env
            . ${GET_PASSWD} 
            if [[  -z "$PASSWD" ]];then
               echo "could no get the password of $S_USER"
               exit 0
            fi
            sqlplus -L  $S_USER/"$PASSWD"
            # reset to normal
            if [ -n "$BGRED" ];then
               unset BGRED
               echo "\033[m"
            fi
            break
         fi
       else
            print -u2 "Invalid choice"
       fi
done

