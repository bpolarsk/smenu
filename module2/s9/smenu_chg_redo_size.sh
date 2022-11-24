#!/usr/bin/ksh
set -xv
SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

if [ -z "$1" ] ;then
   echo "Size of redo logs (in megs : ) ==> \c"
   read ff
else
   ff=$1
fi
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

FOUT=$SBIN/tmp/change_${ORACLE_SID}_redo_size.sql
FOUT1=$SBIN/tmp/ff_tmp$$.txt1
FOUT2=$SBIN/tmp/ff_tmp$$.txt2
FOUT4=$SBIN/tmp/ff_tmp$$.sql
echo "set feed off head off pause off" >> $FOUT4
echo "select group# from v\$log where status = 'CURRENT';" >> $FOUT4
echo "exit" >> $FOUT4
sqlplus -s "$CONNECT_STRING" >$FOUT1 <<EOF
set head off pause off feed off
set linesize 1024 trimspool on
select  l.group#, member, archived, l.status,
        (bytes/1024/1024) fsize
from    v\$log l, v\$logfile f
where f.group# = l.group#
order by 1
/
EOF

CURR_LOG=`grep "CURRENT" $FOUT1 | awk '{print $1}'`
echo "Active  at start ==> $CURR_LOG"
echo "last_f" >> $FOUT1
OLD=-1
> $FOUT
cat >> $FOUT <<EOF

rem Cut and paste the command you need from this file in 'sqlplus / as sysdba'
rem Use 'alter system switch logfile' to change the current
rem logfile if it is the active one. Oracle does not allow
rem to drop active log file, so you must force a switch.
rem use shortcut 'rdl' of smenu to see logfile group status

EOF

if [ -f $FOUT1 ];then
   while read a b c d
    do
      if [ -z "$a" ];then
         continue
      fi
echo "a=$a"
echo "b=$b"
echo "c=$c"
echo "d=$d"
      if [ "$OLD" = "$a"  -o "$OLD" = -1 ];then
          echo "$b" >> $FOUT2
          if [ $OLD = -1 ];then
              echo "prompt Start processing group $a" >> $FOUT
              echo "prompt ==========================" >> $FOUT
              echo " " >> $FOUT
          fi
      else
         if [ -s $FOUT2 ];then
            echo "alter database drop logfile group $OLD ;" >> $FOUT
            while read memb
             do
                 if [ -n "$memb" ]; then 
                    continue
                 fi
                 echo "host mv $memb $memb.old" >> $FOUT
            done<$FOUT2
            echo "alter database $ORACLE_SID add logfile group $OLD \n       ( \c" >> $FOUT
            comma=
            while read memb
             do
               echo "$comma \c" >> $FOUT
               echo "$memb" |grep '^+' 1>/dev/null 2>&1 
               ret=$?
               if [ "$ret" -eq 0 ];then
                   var=`echo $memb | cut -f1 -d'/'`         
                   echo "'$var'" >> $FOUT
               else
                   echo "'$memb'" >> $FOUT
               fi
               if [ -z "$comma"  ];then
                  comma=,
               fi
            done<$FOUT2
            echo " ) size $ff m ; " >> $FOUT
         fi
         echo $b > $FOUT2
         echo " " >> $FOUT
         if [ "$a" = "last_f" ];then
            break
         fi
         echo "prompt Start processing group $a" >> $FOUT
         echo "prompt ==========================" >> $FOUT
         echo " " >> $FOUT
      fi
      OLD=$a
   done<$FOUT1
fi


if [ -f $FOUT1 ];then
   rm $FOUT1
   rm $FOUT2
   rm $FOUT4
fi

if [ -f $FOUT ];then
    echo " Result in $FOUT "
fi
#if $SBINS/yesno.sh "to review the generated script" DO Y
#    then
#     vi $FOUT
#fi
