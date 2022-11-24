#!/usr/bin/ksh

function help
{
  echo Help!
}

typeset -u OWNER
while [ -n "$1" ]
do
  case "$1" in

   -v ) DO=VIEW ;;
   -u ) OWNER=$1
        DO=COMP
        echo "   User schema to recompile ==> $OWNER " ;;
    * ) help ;; 
  esac
done
S_USER=SYS
CPL=$SBIN/tmp/compilerr_$ORACLE_SID.sql
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $USER"
   exit 0
fi

if [ "DO" = "COMP" ];then

   sqlplus -s "$CONNECT_STRING" <<-EOF  
	set pages 0 feedback on echo off
        spool $CPL
	select 'alter '||decode(u.object_type,'PACKAGE BODY','PACKAGE',object_type)||' '||owner
	||'.'||object_name||' compile ;'
	from dba_objects u, sys.order_object_by_dependency o
	where owner  = upper('$OWNER')             and
              status = 'INVALID'                   and    
              u.object_id  = o.object_id (+)       and    
              u.object_type in ( 'PACKAGE BODY', 'PACKAGE', 'FUNCTION', 'PROCEDURE',
                                  'TRIGGER', 'VIEW' )
         order by o.dlevel DESC
	/
	spool off
	EOF

     if $SBIN/scripts/yesno.sh "to review to compile scripts" DO N
     then
        vi $CPL
     fi
     if $SBIN/scripts/yesno.sh "to execute now" 
     then
        sqlplus -s "$CONNECT_STRING" <<EOF
set pages 0 feedback on echo off
@$CPL
EOF

     fi

elif [ "DO" = "view ]; then
sqlplus -s <<EOF  
	set pages 0 feed off echo off pause off
        select owner,count(*), object_type,status from dba_objects group by owner, object_type,status 
	/
EOF

else
   echo "Unknown option"
fi
