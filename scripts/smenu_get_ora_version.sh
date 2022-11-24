#!/bin/ksh
# Programm	: Get Oracle version
# Author	: Bernard Poalrski
# Date 		: 25-Apr-2000
HOST=`hostname`
SBINS=$SBIN/scripts

# to spare a connection to the DB one can use ORA_VERSION
# ORA_VERSION must be sourced under the form ORA_VERSION=SID1:nn:SID2:nn:SID3:nn:
# where nn is the version of oracle for this SIDn
if [ -n "$ORA_VERSION" ];then
   ret=`echo "$ORA_VERSION" |  sed "s/\(.*\)$ORACLE_SID:\([0-9]*\)\(:.*$\)/\2/"`
   if [ "$ret" -eq "$ret" 2>/dev/null ];then     # a trick to test if it is a number
       echo $ret
       exit
   fi
fi

#-- check if this not an SQLNET SID
S_USER=${S_USER:-SYS}
if [ "$S_USER" = "SYS"   -o $S_USER = 'sys' ];then
   SYSDBA=' as sysdba'
fi
PASSWD=`cat  $SBIN/scripts/.passwd |  grep -i "^${ORACLE_SID}:" | cut -f2- -d':' | grep -i "^${S_USER}:" | cut -f2 -d':'`

if [  -z "$PASSWD" ];then
   if [ $S_USER = 'SYS' -o $S_USER = 'sys' ];then
        S_USER=''
        PASSWD=''
   else
      #echo "could no get a the password of $S_USER"
      S_USER=SYSTEM
      unset SYSDBA
     PASSWD=`cat  $SBIN/scripts/.passwd |  grep -i "^${ORACLE_SID}:" | cut -f2- -d':' | grep -i "^${S_USER}:" | cut -f2 -d':'`
   fi
fi


ORACLE_VERSION=`sqlplus -s "$S_USER/$PASSWD $SYSDBA" <<EOF
set pagesize 0 head off verify off pause off feed off
select substr(version,1,instr(version,'.',1)-1) version from v\\$instance
/
EOF`
ORACLE_VERSION_SHORT=ORACLE_VERSION


# version 10g is ok for 11g, 12c. It is just a code
if [  -z "$ORACLE_VERSION"  -o "$ORACLE_VERSION" = "select" ];then
     ORACLE_VERSION=10
fi
ORACLE_VERSION_SHORT=`echo $ORACLE_VERSION | cut -f1 -d.`
echo $ORACLE_VERSION 

