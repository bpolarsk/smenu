#!/bin/ksh
# set -xv
# smenu_change_SID.sh

if [ -n "$@" ];then
   RAD="$@"
fi

if [ "$LOCAL_ORAENV" = "TRUE" ];then
   PS3=' Select SID ==> '
   if [ -n "$TNS_ADMIN" ];then  
       FILE=$TNS_ADMIN/tnsnames.ora
   else
       FILE=$SBIN/data/tnsnames.$TNS_TARGET
   fi
   if [ "$TNS_TARGET" = "prd" -o "$TNS_TARGET" = "ist" -o "$TNS_TARGET" = "rac" ];then
        FILE="$FILE $SBIN/data/tnsnames.add"
   fi
   if [ -n "$RAD" ];then
      SIDLIST=`cat  $FILE | grep -v -e '(' -e ')' | grep = | tr -d '=' | tr ',' '\n' | grep -v '#' | sort -u | sed 's/ //g'| tr '' ' ' | grep -v '\.' | grep -i $RAD | tr '\n' ' '`
   else
      SIDLIST=`cat  $FILE | grep -v -e '(' -e ')' | grep = | tr -d '=' | tr ',' '\n' | grep -v '#' | sort -u | sed 's/ //g'| tr '' ' ' | grep -v '\.' | tr '\n' ' '`
   fi
else
   OS=`uname | awk '{print $1}'`
   case $OS in
     AIX   ) ORATAB=/etc/oratab ;;
     HP-UX ) ORATAB=/etc/oratab ;;
     CYG*  ) ORATAB=/etc/oratab ;;
     Linux ) ORATAB=/etc/oratab ;;
     SunOS ) ORATAB=/var/opt/oracle/oratab ;;
      *    ) if [ -f /etc/oratab ];then
             ORATAB=/etc/oratab
          elif [ -f /var/opt/oracle/oratab ];then
             ORATAB=/var/opt/oracle/oratab
          else
            echo "I did not find the Oratab ! "
            echo " Edit he file $0 and update the ORATAB locatction. "
            return
          fi
           ;;
   esac
   PS3=' Select SID ==> '
   #SIDLIST=` awk -F: '/^[^#^\*]/ { printf "%s ", $1 } ' $ORATAB | tr -d '*'| tr ' ' '\n' | sort -u | tr '\n' ' '`
   if [ -n "$RAD" ];then
       SIDLIST=`cat $ORATAB | cut -f1 -d: | grep -v ^[#] | grep -v '^ '| grep -i $RAD `
   else
       SIDLIST=`cat $ORATAB | cut -f1 -d: | grep -v ^[#] | grep -v '^ '`
   fi
fi

echo " "
echo " "
echo " Instances :"
echo " "
echo " "
select SID in ${SIDLIST}
   do
      if [[ -n ${SID} ]]; then
         ORAENV_ASK=NO
         ORACLE_SID=${SID} ; export ORACLE_SID
         export ORAENV_ASK ORACLE_SID
         break
      else
         print -u2 "Invalid choice"
      fi
done

