#!/usr/bin/ksh
#set -xv
SBINS=$SBIN/scripts
WK_SBIN=$SBIN/module2/s1
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`

if [ -z "$1" ];then
  echo $NN "Size of redo logs (in megs : ) ==> $NC"
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
(sqlplus -s "$CONNECT_STRING"  <<EOF
set head off pause off feed off verify off
set linesize 150
select  to_char(l.group#)|| ' ' || trim(member) || ' '|| archived || ' '|| l.status|| ' '||to_char((bytes/1024/1024))  
        from v\$log l, v\$logfile f where f.group# = l.group# order by 1
/
EOF
) > $FOUT1

CURR_LOG=`grep "CURRENT" $FOUT1 | awk '{print $1}'`
echo "Active  at start ==> $CURR_LOG"
echo "last_f" >> $FOUT1
OLD=-1
> $FOUT
cat >> $FOUT <<EOF
exit

    Remove the exit above, if you crazy enough to run this script as it. 
           -if the script fails, you probably lost the DB.
           -if it worked out of the box, you spared 1 min
    my advice is do each step at a time and always have a look at where 
    is the current REDO group.

    Cut and paste the command you need from this file 'sqlplus /nolog'
    Use 'alter system switch logfile' to change the current
    logfile if it is the active one. Oracle does not allow
    to drop active log file, so you must force a switch.
    use shortcut 'rdl' of smenu to see logfile group status

EOF
if [ -f $FOUT1 ];then
   while read a b c d
    do
      if [ -z "$a"  ];then
         continue
      fi
      if [ $OLD = $a  -o $OLD = -1 ];then
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
                 echo "host rm $memb " >> $FOUT
            done<$FOUT2
            echo $NN "alter database $ORACLE_SID add logfile group $OLD \n       ( $NC" >> $FOUT
            comma=
            while read memb
             do
               echo $NN "$comma $NC" >> $FOUT
               echo "'$memb'" >> $FOUT
               if [ "x-$comma" = "x-" ];then
                  comma=,
               fi
            done<$FOUT2
            echo " ) size $ff m ; " >> $FOUT
         fi
         echo $b > $FOUT2
         if [ "x-$a" = "x-last_f" ];then
            break
         fi
         echo " " >> $FOUT
         echo "prompt Start processing group $a" >> $FOUT
         echo "prompt ==========================" >> $FOUT
         echo " " >> $FOUT
      fi
      OLD=$a
   done<$FOUT1
fi


if [ -f $FOUT1 ];then
   rm $F$NN $FOUT1
   rm $FOUT2
   rm $FOUT4
fi

if [ -f $FOUT ];then
    echo " Result in $FOUT "
fi
if $SBINS/yesno.sh "to review the generated script" DO Y
    then
     vi $FOUT
fi
