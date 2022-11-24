#!/bin/sh
#Date    : 30/08/2005
#Program : update_locate_owb_rt_par.ksh
#Author  : Polarski

TNS_ADMIN=/var/opt/oracle
function help
{
cat <<EOF

       update_locate_owb_rt_par.ksh \$ORACLE_SID

       In order to run this script, you must 
        
              - Be in the RT ORACLE_SID, not the OWB one,
              - Have the proper TNS entry of the RT set on this server,
              - Have the OWB home set in the oratab


   for more information, read metalink 289883.1
   *******************************************************************************************
   !!!! Check also <xxx>_RT_REP.OWB_RT_STORE_PARAMETERS and adapt the connect string if needed
   *******************************************************************************************

EOF
}

while true 
do
  if [ -z "$1" ];then
     break
  fi

  case $1 in
    -h ) help 
         exit ;;
     * ) LST=`cat $TNS_ADMIN/oratab | cut f1 -d:`

         if [ -n "${ORACLE_SID## $LST *}" ];then
            echo "Oracle SID not found "
            exit
         fi
         ;;
   esac
   shift
done
CONNECT_STRING='/ as sysdba'

OWB_RT_LIST=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off feed off pause off
select username from dba_users where username like '%RT_REP';
EOF`


echo $OWB_RT_LIST | while read a
do
  if [ -z $a ];then
      continue
  fi
  echo "Processing $a"
  sqlplus -s "$CONNECT_STRING" <<EOF
  set linesize 132 feed off head on
  col  host format A13 head 'Host'
  col service_name format A17 head "Service name"
  col runtime_version format A20 head "Run time Version"
  col server_side_home format A45 head "Oracle Home"
  col Key format A14 head "Key"
  
  select Key, host, port, service_name, runtime_version, server_side_home from
         owbrt_sys.owbrtps   , $a.wb_rt_service_nodes 
          where  value = server_side_home ;
  exit
EOF
 

  OWB_HOME=`grep -i ^owb $TNS_ADMIN/oratab | cut -f2 -d:`
  PORT=`tnsping $ORACLE_SID | grep DESCRIPTION | tr '(' '\n' | grep ^PORT| sed -e 's/PORT=//' -e 's/)//g'`
  HOST=`hostname |cut -f1 -d'.'`
  var=`sqlplus -s "$CONNECT_STRING" <<EOF
                   set feed off head off 
                   select key from owbrt_sys.owbrtps ;
EOF`
  typeset -l SERVICE_NAME 
  SERVICE_NAME=$ORACLE_SID
  RUNTIME_VERSION=`echo $var | awk '{print $1}' | cut -f1 -d'['` 
  SERVER_SIDE_HOME=$OWB_HOME
  cat <<EOF

       Ready to upate $a.wb_rt_service_nodes with  (y) : 

           HOST                =  $HOST
           PORT                =  $PORT
           OWB_HOME            =  $OWB_HOME
           RUNTIME_VERSION     =  $RUNTIME_VERSION
           SERVICE_NAME        =  $SERVICE_NAME
           SERVER_SIDE_HOME    =  $OWB_HOME
  
EOF
      sqlplus -s "$CONNECT_STRING" <<EOF
      update  owbrt_sys.owbrtps set value = '$OWB_HOME' ;
      update  $a.wb_rt_service_nodes set  HOST='$HOST', 
                                          PORT=$PORT, 
                                          SERVICE_NAME='$SERVICE_NAME', 
                                          RUNTIME_VERSION='$RUNTIME_VERSION', 
                                          SERVER_SIDE_HOME='$OWB_HOME'  ;
      commit ;
EOF
    
done

