#!/usr/bin/ksh
# author   ; Polarski bernard
# date     : 10 Jun 2009
# Program  : smenu_create_ext_table.ksh
# set -x
# -------------------------------------------------------------------------------------------------
function help
{
cat <<EOF
  This script check and create an external table named after a given flat file. It handle also the Oracle Drectory

    mxt  -f <file_in> [-u <SCHEMA>] [-n <TBL_NAME>] [-d <ORACLE_DIRECTORY_NAME>] [-l <DELIMITER CHAR>

   
   creates into oracle an external table definition for file 'file_lin' with one column of one line varchar2(1024) 
   The oracle directory path will match the dirname of the file.
 
Optionals parameters:

    -n    <TBL_NAME>                      # table name in oracle. Default is uppercase of filename up to the first '.'
    -d    <ORACLE_DIRECTORY_NAME>         # Use oracle directory. Default is to check path into filename. if no path
                                          # then current PWD is taken. an Oracle Directory is created for this dir
    -l    <DELIMITER CHAR>                # Default delimiter is space or set it yourself. 
    -u    <SCHEMA>                        # Who shall be granted the SELECT on this external table

EOF
exit
}
# -------------------------------------------------------------------------------------------------
function check_exists_ext_table 
{
  v_owner=$1
  v_table=$2
  v_oradir=$3
  v_location=$4

   if [ ! "$v_owner" = 'SYS' ];then
       AND_OWNER=  " and owner = upper('$v_owner') "
   fi 
var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select count(1) 
   from dba_external_locations 
   where table_name = upper('$v_table') and DIRECTORY_NAME = upper('$v_oradir') and LOCATION='$v_location' $AND_OWNER;
EOF`
echo $var
}
# -------------------------------------------------------------------------------------------------
function check_ora_dir_exists
{
    v_dir=$1
    v_fil=$2
    var=`sqlplus -s "$CONNECT_STRING" <<EOF
    set feed off pagesize 0 head off
select count(*) from all_directories where DIRECTORY_NAME=upper('$v_dir') and DIRECTORY_PATH='$v_fil';
EOF`
echo $var
}
# -------------------------------------------------------------------------------------------------
function create_ext_table
{
  v_table=$1
  v_oradir=$2
  v_location=$3
sqlplus -s "$CONNECT_STRING" <<EOF
CREATE TABLE $v_table
         (
           FLINE                           VARCHAR2(1024)
	 )
  ORGANIZATION EXTERNAL
    ( DEFAULT DIRECTORY $v_oradir
      LOCATION ('$v_location') ) ;
EOF
    #( TYPE ORACLE_LOADER DEFAULT DIRECTORY $v_oradir ACCESS PARAMETERS
      #( RECORDS DELIMITED BY NEWLINE NOLOGFILE NOBADFILE MISSING FIELD VALUES ARE NULL)
      #LOCATION ('$v_location') ) REJECT LIMIT UNLIMITED;
}
# -------------------------------------------------------------------------------------------------
function create_directory
{
   v_dir=$1
   v_path=$2
   if [ ! "$fowner" = "SYS" ];then
       SQL="grant read,write on directory $v_dir to $fowner ;"
   fi
# note that we use 'create' and not 'create or replace'. If you are here the directory is not supposed to exists
# if it exists then it had a wrong path. it is up to you to manage this
sqlplus -s "$CONNECT_STRING" <<EOF
    set feed off pagesize 0 head off
    create directory  $v_dir as '$v_path' ;
    $SQL
EOF
}
# -------------------------------------------------------------------------------------------------
#                                        Main
# -------------------------------------------------------------------------------------------------
if [ -z  "$1"  ];then
   help
fi

typeset -u ftable
typeset -u fowner

while [ -n "$1" ] 
do
  case "$1" in
    -d ) ora_dir=$2    ; shift ;;
    -l ) DELIM=$2      ; shift ;; 
    -n ) ftable=$2     ; shift ;; 
    -u ) fowner=$2     ; shift ;; 
    -f ) FIN=$2        ; shift ;; 
    -h ) help ;;
     * ) echo "invalid argument : $1" ; exit ;;
  esac
  shift
done

fowner=${fowner:-SYS}
ora_dir=`echo $ora_dir|cut -c1-30`             # trunc to name to max 30 characters
fpath=`dirname $FIN`                # full path name of the file
fname=`basename $FIN`              
fname30=`echo $fname | cut -f1 -d'.'`
fname30=`echo $fname30|cut -c1-30`

if [ "$fpath" = "." ];then fpath=$PWD  ; fi
ora_dir_found=false

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi 

user_dump_dest=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select value from v\\$parameter where name = 'user_dump_dest';
EOF`
# if a dir_name is given, check it exists and match the file path
if [ -n "$ora_dir" ];then
    ret=`check_ora_dir_exists $ora_dir $fpath`
    if [ $ret -gt 0 ];then
       ora_dir_found=true
    else
        echo "Directory name $ora_dir is given but no match find in ALL_DIRECTORIES with path '$fpath'"
    fi
else # no directory given, let's try to discover one using he filaname `dirname`
    # The max(DIRECTORY_NAME) is to restrict retunr value to only one, if many aliases exists
    # in this case we may run in schema grant directory issues. 
    ora_dir=`sqlplus -s "$CONNECT_STRING" <<EOF
    set feed off pagesize 0 head off
select max(DIRECTORY_NAME) from all_directories where DIRECTORY_PATH='$fpath';
EOF`
    len=`echo $ora_dir | awk '{print length($1)}'`
    if [ $len -gt 0 ]; then
         ora_dir_found=true
    fi      
fi
if [ "$ora_dir_found" = "false" ];then
   if [ -z "$ora_dir" ];then
      ora_dir=`basename $fpath`               # take as default name the directory name of the file 
      ora_dir=`echo $ora_dir|cut -c1-30`
   fi
   create_directory $ora_dir $fpath
fi

#does the external table already exists are the correct location
ret=`check_exists_ext_table $fowner $fname30 $ora_dir $fname`
if [  "$ret" -eq 0 ];then
     create_ext_table $fname30 $ora_dir $fname
fi
# ---------------------------------
# now we execute the awk built
# ---------------------------------
