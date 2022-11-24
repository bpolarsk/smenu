#!/bin/sh
# author : B. Polarski
# date   : 29 September 2006
# Program: smenu_sample_to_db.ksh  
# Notes  : This program creates the tables for the sampler
# set -x
if echo "\c" | grep c >/dev/null 2>&1; then
    NN='-n'
    unset NC
else
    NC='\c'
    unset NN
fi

# ------------------------------------------------------------------------------------
function is_tbl_exists {
   ret=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select count(1) from user_tables where table_name = '$1' ;
EOF`
echo $ret
}
# ------------------------------------------------------------------------------------
function help
{
 more <<EOF


        spl -cr_tbl                : Create the sample dir table
        spl -dr_tbl                : Create the sample dir table

EOF
 exit
}
# ------------------------------------------------------------------------------------

while [ -n "$1" ]; do
   case "$1" in
     -dr_tbl ) ACTION=DROP ;;
     -cr_tbl ) ACTION=CREATE ;;
           -p) F_PASS=$2 ; shift ;;
         -rn ) ROWNUM=$2 ; shift ;;
           -u) F_USER=$2 ; shift ;;
           -h) help ;;

   esac
   shift
done

# 
# if user and pass are given, make it the connect string and table schema
# if not, use S_USER value as target creation table schema. By default it is SYS
# 
if [ -n "$F_USER" ];then
    S_USER=$F_USER
fi
if  [ -n "$F_PASS" ];then
    CONNECT_STRING=$F_USER/$F_PASS
else
    . $SBIN/scripts/passwd.env
    . ${GET_PASSWD} $S_USER $ORACLE_SID
    if [  "x-$CONNECT_STRING" = "x-" ];then
       echo "could no get a the password of $S_USER"
       exit 0
    fi
fi

if [ $ACTION  = "DROP" ];then
   SQL="prompt table : sample_delta_w
   drop table sample_delta_w;"
   prompt table : sample_txt_w
   drop table sample_txt_w;"

elif [ $ACTION  = "CREATE" ];then

     # The figures out of V$SQL
     ret=`is_tbl_exists SAMPLE_DELTA_W|awk '{print $1}'`
     if [ $ret -lt 1  ];then
        SQL="prompt table : sample_delta_w
            create table sample_delta_w (
            DDATE                            VARCHAR2(14),
            HASH_VALUE                       NUMBER,
            ROWS_PROCESSED                   NUMBER,
            DISK_READS                       NUMBER,
            FETCHES                          NUMBER,
            EXECUTIONS                       NUMBER,
            LOADS                            NUMBER,
            PARSE_CALLS                      NUMBER,
            BUFFER_GETS                      NUMBER,
            SORTS                            NUMBER,
            CPU_TIME                         NUMBER,
            FIRST_LOAD_TIME                  VARCHAR2(19),
            PLAN_HASH_VALUE                  NUMBER,
            CHILD_NUMBER                     NUMBER,
            MODULE                           VARCHAR2(64));"

   fi

   # The SQL text
   ret=`is_tbl_exists SAMPLE_TXT_W|awk '{print $1}'`
   if [ $ret -lt 1  ];then
   SQL_1="prompt table : sample_txt_w
       create table sample_txt_w  (
            HASH_VALUE                        Number,
            piece                             NUMBER,
            SQL_TEXT                          varchar2(64)
        );"

   # The waits from v$session_waits
   ret=`is_tbl_exists SAMPLE_SQL_W|awk '{print $1}'`
   if [ $ret -lt 1  ];then
   SQL_1="prompt table : sample_sql_w
CREATE TABLE sample_sql_w
         (
            DDATE                                  VARCHAR2(14),
            SID                                    NUMBER,
            SEQ#                                   NUMBER,
            EVENT#                                 NUMBER,
            EVENT                                  VARCHAR2(64),
            WAIT_TIME                              NUMBER,
            SECONDS_IN_WAIT                        NUMBER,
            P1                                     NUMBER,
            P1RAW                                  VARCHAR2(16),
            P1TEXT                                 VARCHAR2(64),
            P2                                     NUMBER,
            P2RAW                                  VARCHAR2(16),
            P2TEXT                                 VARCHAR2(64),
            P3                                     NUMBER,
            P3TEXT                                 VARCHAR2(64),
            SQL_HASH_VALUE                         Number,
            PREV_HASH_VALUE                        Number,
            ROW_WAIT_OBJ#                          Number
        )

fi

# now we do the action

    sqlplus -s "$CONNECT_STRING" <<EOF
$SQL
$SQL_1
$SQL_2
EOF

