#!/bin/ksh
# set -xv
#-------------------------------------------------------------------------------
#-- Purpose:	Display object tree
#-- Author:	Jacques Kilchoer
#__ adapted to smenu by By. Polarski
#              Fixed query wich returned mutliple rows when object name exists in many schema
#-------------------------------------------------------------------------------
function help
{
cat <<EOF

      dep <OBJ>      -u <OWNER>    # list  on which others object <OBJ> is dependent
      dep -p  <OBJ>  -u <OWNER>    # List  which objects are dependent on <OBJ> from dba_dependencies
      dep -pl <OBJ>  -u <OWNER>    # List all plan associated with OBJ
      dep -t <TABLE> -u <OWNER>    # List all physical objects name and id dependent from a table
      dep -lsv -u <OWNER>          # List all grants tables needed for views of a user

EOF
exit
}
OWNER=''
if [ -z "$1"  ];then
   help
fi
typeset -u OWNER
typeset -u OBJ
CHOICE=DEFAULT
while [ -n "$1" ]
do
  case "$1" in
     -u ) OWNER=$2; shift ;;
     -t ) CHOICE=DEPT ; ftable=$2 ; shift ;;
     -p ) CHOICE=DEP ;;
     -lsv ) CHOICE=LIST_VIEW_DEP ;;
    -pl ) CHOICE=DEP_PLAN ;;
     -v ) set -x ;;
     -h ) help ;;
      * ) OBJ=$1 ;;
  esac
  shift
done
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID
if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
# ----------------------------------------------------------------------
if [ -n "$ftable" -a -z "$fowner" ];then
   ftable=`echo $ftable | awk '{print toupper($1)}'`
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select  trim(to_char(count(*))) cpt from dba_tables where table_name='$ftable' ;
EOF`
   ret=`echo "$var" | tr -d '\r' | awk '{print $1}'`
   if [ -z "$ret" ];then
      echo "Currently, there is no entry in dba_tables for $ftable"
      exit
   elif [ "$ret" -eq "0" ];then
     echo "Currently, there is no entry in dba_tables for $ftable"
     exit
  elif [ "$ret" -eq "1" ];then
   var=`sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 0 head off
select owner from dba_tables where  TABLE_NAME='$ftable' and rownum=1 ;
EOF`
     fowner=`echo "$var" | tr -d '\r' | awk '{print $1}'`
     FOWNER="owner = '$fowner' "
     AND_FOWNER=" and  $FOWNER"
     A_FOWNER=" a.owner = '$fowner'"
  elif [ "$ret" -gt "0"  ];then
       if [ -z "$fowner" ];then
         echo " there are many tables for $ftable:"
         echo " Use : "
         echo
         echo " tbl -t $ftable -u <user> "
         echo
      sqlplus -s "$CONNECT_STRING" <<EOF
set feed off pagesize 66 head on
select owner, table_name , 'table' from dba_tables where table_name='$ftable' ;
EOF
         exit
       fi
   fi
fi

# ----------------------------------------------------------------------
if [ "$CHOICE" = "LIST_VIEW_DEP" ];then

sqlplus -s " $CONNECT_STRING" <<EOF
    
set lines 190 pages 0
   select  distinct 'grant select on '||referenced_owner ||'.'|| referenced_name || ' to $OWNER ;' 
   from ALL_DEPENDENCIES where owner=upper('$OWNER') and type = 'VIEW'  and referenced_owner <> upper('$OWNER') 
/
EOF
exit
elif [ "$CHOICE" = "DEPT" ];then

fowner=`echo $fowner | awk '{print toupper($1)}'`
sqlplus -s " $CONNECT_STRING" <<EOF
    
set lines 190 pages 66
col name for a30
col object_type head 'Object type' for a16
with v as (
select owner, object_name table_name, OBJECT_ID , data_object_id, object_type ftype
      from dba_objects 
      where 
            OBJECT_TYPE = 'TABLE' 
        and owner = '$fowner' 
        and OBJECT_NAME ='$ftable'
)
, vp as ( 
select o.owner, o.SUBOBJECT_NAME, o.OBJECT_ID, o.data_object_id, o.object_type ftype
           from  v , dba_objects o
                where
                    o.owner = v.owner
                and o.object_name = v.table_name
                and o.object_type in ( 'TABLE PARTITION' , 'TABLE SUBPARTITION')
)
, vi as ( select i.owner , index_name name ,  o.OBJECT_ID , o.data_object_id, o.object_type ftype
         from dba_indexes i,  v , dba_objects o
          where  v.owner = i.owner and v.table_name = i.table_name 
             and o.OBJECT_NAME = i.index_name
             and o.owner = i.owner
             and o.object_type = 'INDEX'
          )
, vpi as ( select vi.owner, o.SUBOBJECT_NAME, o.OBJECT_ID, o.data_object_id, o.object_type
           from  vi , dba_objects o
                where
                       o.owner = vi.owner
                   and o.object_name = vi.name
                   and o.object_type in ( 'INDEX PARTITION', 'INDEX SUBPARTITION')
)
, vl as ( select  l.owner, l.segment_name, o.OBJECT_ID, l.table_name, o.data_object_id, o.object_type ftype
             from 
                   dba_lobs l, v, dba_objects o
             where 
                   l.owner = v.owner
               and l.table_name = v.table_name
               and o.object_name = l.segment_name
               and o.owner       = l.owner
               and o.object_type = 'LOB'
)
, vlp as ( select  lp.table_owner, lp.lob_partition_name, o.OBJECT_ID, o.data_object_id, o.object_type ftype
             from 
                   dba_lob_partitions lp, vl, dba_objects o
             where 
                  lp.table_owner = vl.owner
               and lp.table_name  = vl.table_name
               and lp.lob_name    = vl.segment_name
               and o.object_name  = lp.lob_name
               and o.subobject_name = lp.LOB_PARTITION_NAME
               and o.owner       = vl.owner
               and o.object_type in ( 'LOB PARTITION','INDEX PARTITION')
)
,vlpi as (
    select -- /*+ leading( v l pi o ) */
            pi.index_owner as owner , PARTITION_NAME , o.OBJECT_ID , o.data_object_id, o.object_type ftype
   from
         v, dba_part_lobs l , dba_ind_partitions pi
         , dba_objects o
   where
         l.table_owner = v.owner
     and l.table_name = v.table_NAME
     and pi.index_owner = l.table_owner
     and pi.index_name =  l.LOB_INDEX_NAME
      and o.owner       = l.table_owner
      and o.object_name = l.lob_index_name
     and o.subobject_name =  pi.PARTITION_NAME
     and o.object_type ='INDEX PARTITION'
)
, viot as (  select   i.owner, i.index_name ,  o.OBJECT_ID, o.data_object_id, o.object_type as ftype
             from
                  dba_tables t ,
                  v , dba_indexes i , dba_objects o
              where
                       t.owner      = v.owner
                   and t.table_name   = v.table_name
                    and i.owner      = t.owner
                    and i.table_name = t.iot_name
                    and o.owner = i.owner
                    and o.OBJECT_NAME = i.index_name
                    and o.object_type = 'INDEX'
)
select  owner, table_name name, object_id , data_object_id, ftype from v
union
select * from vi
union
select * from vp
union
select * from vpi
union
select owner, segment_name name, OBJECT_ID, data_object_id, ftype  from vl
union
select * from vlp
union
select * from vlpi
union
select * from viot
/
EOF
exit
# ----------------------------------------------------------------------
#  Based on an idea of Jonathan Lewis
# ----------------------------------------------------------------------
elif [ "$CHOICE" = "DEP_PLAN" ];then
   if [ -n "$OWNER" ];then
        AND_OWNER=" and to_owner = '$OWNER'"
   fi
sqlplus -s " $CONNECT_STRING" <<EOF
prompt 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  
column nline newline
set head off lines 124 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'List all plan associated with object' from sys.dual
/   
set pagesize 66 linesize 190 termout on pause off embedded on verify off heading  off 
select
        t.plan_table_output
from    (
        select
                sql_id, child_number
        from
                V\$sql
        where
                hash_value in (
                        select  from_hash
                        from    V\$object_dependency
                        where   
                             to_name = '$OBJ' $AND_OWNER )
        ) v,
        table(dbms_xplan.display_cursor(v.sql_id, v.child_number)) t;
EOF

# ----------------------------------------------------------------------
elif [ "$CHOICE" = "DEP" ];then


if [ -n "$OWNER" ];then
   AND_OWNER="and owner = '$OWNER'"
fi

sqlplus -s " $CONNECT_STRING" <<EOF

prompt 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  
column nline newline
set head off lines 124 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'Objects on which $OBJ is dependent' from sys.dual
/   
set pages 90 linesize 157 termout on pause off embedded on verify off heading on
col object_name for a30
col object_type for a18

SELECT object_name, object_type, owner, status, last_ddl_time 
       FROM dba_objects WHERE ( owner, object_name, object_type ) IN 
         ( SELECT  owner, name, type FROM dba_dependencies WHERE REFERENCED_NAME = '$OBJ' ) 
/
EOF
exit
else # choice = default
sqlplus -s " $CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '  right 'Page:' format 999 sql.pno skip 2
column nline newline
set pagesize 66 linesize 90 termout on pause off embedded on verify off heading off
 
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  nline , 'Objects that depends on $OBJ' from sys.dual
/   
set linesize 190 pagesize 66
set heading on
col owner format a20
col a format a30 head Name
col b format a30 head constraint
select lpad(' ',(a.nivel-1)*2)||obj.name a,
           decode(obj.type#, 0, 'NEXT OBJECT', 1, 'INDEX', 2, 'TABLE', 3, 'CLUSTER',
                      4, 'VIEW', 5, 'SYNONYM', 6, 'SEQUENCE',
                      7, 'PROCEDURE', 8, 'FUNCTION', 9, 'PACKAGE',
                      11, 'PACKAGE BODY', 12, 'TRIGGER',
                      13, 'TYPE', 14, 'TYPE BODY',
                      19, 'TABLE PARTITION', 20, 'INDEX PARTITION', 21, 'LOB',
                      22, 'LIBRARY', 23, 'DIRECTORY', 24, 'QUEUE',
                      28, 'JAVA SOURCE', 29, 'JAVA CLASS', 30, 'JAVA RESOURCE',
                      32, 'INDEXTYPE', 33, 'OPERATOR',
                      34, 'TABLE SUBPARTITION', 35, 'INDEX SUBPARTITION',
                      40, 'LOB PARTITION', 41, 'LOB SUBPARTITION',
                      42, NVL((SELECT distinct 'REWRITE EQUIVALENCE'
                               FROM sys.sum$ s WHERE s.obj#=obj.obj# and bitand(s.xpflags, 8388608) = 8388608), 'MATERIALIZED VIEW'),
                      43, 'DIMENSION',
                      44, 'CONTEXT', 46, 'RULE SET', 47, 'RESOURCE PLAN',
                      48, 'CONSUMER GROUP',
                      51, 'SUBSCRIPTION', 52, 'LOCATION',
                      55, 'XML SCHEMA', 56, 'JAVA DATA',
                      57, 'SECURITY PROFILE', 59, 'RULE',
                      60, 'CAPTURE', 61, 'APPLY',
                      62, 'EVALUATION CONTEXT',
                      66, 'JOB', 67, 'PROGRAM', 68, 'JOB CLASS', 69, 'WINDOW',
                      72, 'WINDOW GROUP', 74, 'SCHEDULE', 79, 'CHAIN',
                      81, 'FILE GROUP',
                     'UNDEFINED') type,
           u.name owner,
       lpad(' ',(a.nivel-1)*2)||cons.name b  , 
       to_char(obj.mtime,'YYYY-MM-DD HH24:MI:SS')Last_modified,
decode(obj.status, 0, 'N/A', 1, 'VALID', 'INVALID') status
from   sys.obj$ obj,
       sys.user$ u,
       sys.con$ cons,
       (
        select obj# obj#,
               con#,
               level nivel
        from sys.cdef$
        where rcon# is not null AND
              robj# is not null
        connect by robj# = prior obj# and
                   robj# != obj#      and
                   prior robj# != prior obj#
        start with robj# = (select obj# from  sys.obj$,sys.user$ where  obj$.name = upper('$OBJ') AND obj$.type# = 2
                                 and obj$.type#=2 and sys.obj$.owner# = sys.user$.user# and sys.user$.name = '$OWNER'
        )) a
where   cons.con# = a.con# AND
        obj.obj#  = a.obj# AND
        obj.owner#=u.user# AND
        obj.type# = 2
UNION ALL
select lpad(' ',(a.nivel-1)*2)||obj.name a,
           decode(obj.type#, 0, 'NEXT OBJECT', 1, 'INDEX', 2, 'TABLE', 3, 'CLUSTER',
                      4, 'VIEW', 5, 'SYNONYM', 6, 'SEQUENCE',
                      7, 'PROCEDURE', 8, 'FUNCTION', 9, 'PACKAGE',
                      11, 'PACKAGE BODY', 12, 'TRIGGER',
                      13, 'TYPE', 14, 'TYPE BODY',
                      19, 'TABLE PARTITION', 20, 'INDEX PARTITION', 21, 'LOB',
                      22, 'LIBRARY', 23, 'DIRECTORY', 24, 'QUEUE',
                      28, 'JAVA SOURCE', 29, 'JAVA CLASS', 30, 'JAVA RESOURCE',
                      32, 'INDEXTYPE', 33, 'OPERATOR',
                      34, 'TABLE SUBPARTITION', 35, 'INDEX SUBPARTITION',
                      40, 'LOB PARTITION', 41, 'LOB SUBPARTITION',
                      42, NVL((SELECT distinct 'REWRITE EQUIVALENCE'
                               FROM sys.sum$ s WHERE s.obj#=obj.obj# and bitand(s.xpflags, 8388608) = 8388608), 'MATERIALIZED VIEW'),
                      43, 'DIMENSION',
                      44, 'CONTEXT', 46, 'RULE SET', 47, 'RESOURCE PLAN',
                      48, 'CONSUMER GROUP',
                      51, 'SUBSCRIPTION', 52, 'LOCATION',
                      55, 'XML SCHEMA', 56, 'JAVA DATA',
                      57, 'SECURITY PROFILE', 59, 'RULE',
                      60, 'CAPTURE', 61, 'APPLY',
                      62, 'EVALUATION CONTEXT',
                      66, 'JOB', 67, 'PROGRAM', 68, 'JOB CLASS', 69, 'WINDOW',
                      72, 'WINDOW GROUP', 74, 'SCHEDULE', 79, 'CHAIN',
                      81, 'FILE GROUP',
                     'UNDEFINED') type,
           u.name owner,
       to_char(null),
       to_char(obj.mtime,'YYYY-MM-DD HH24:MI:SS')Last_modified,
      decode(obj.status, 0, 'N/A', 1, 'VALID', 'INVALID') status
from   sys.obj$ obj,
       sys.user$ u,
       (
        select d_obj# obj#,
               level nivel
        from sys.dependency$
        connect by p_obj# = prior d_obj#
        start with p_obj# = (select obj#
                             from   sys.obj$,sys.user$ where  obj$.name = upper('$OBJ') and obj$.type#=2 and 
                                      sys.obj$.owner# = sys.user$.user# and sys.user$.name = '$OWNER'
        )) a
where  obj.obj#  = a.obj#
       AND obj.type# != 2
       AND obj.owner#=u.user#
/
EOF
fi
