#!/bin/ksh
# author     : B.Polarski
# program    : smenu_show_obj.ksh
# date       : 1999 reviewed 20 October 2006
# usage      : Retrieve all sorts of info about objects in DB
#
#              2007 AUg 10 : added: obj -t to list objects by type and owner
#set -x

TITTLE="List extents occupancy for an object"
ROWNUM=30
function help
{
      cat <<EOF

      obj -o <OBJ_NAME> -dt           # Display object name whose name is given (multi answers possible) -dt sort by date
      obj -n <nn>                     # Display object whose number (object_id) is given:
      obj -dn <DATA_OBJ_NAME> -dt     #  Display object whose data object id
      obj -xt [ -tbs <tablepsace>]    # Display object with not enought space for next extents
      obj -f  <FILE_ID> -b block_id   # Display object    given by file and block id:
      obj -ff <FILE_ID> -b block_id   # faster way to get source object name of db cached block, but only for locally managed tbs (requiers 'SYS').
                                      # use 'frg -i' to see which tablespsace are locally managed.
      obj -ddl [ -w <OWNER> ] [-rn <nn>]         # list object by last ddl time, restrict display to <nn> rows limited to <OWNER>
      obj -f <FILE_ID> -dba <dba block address>  # Display object whose dba is given (DBA block address is obtain from 'dbv' utility)
      obj -dump -f <FILE_ID> -b <BLOCK_ID>       # dump datafile block
      obj -siz <OBJ_NAME>  [-w <OWNER>]          # check size against dba_segments
      obj -lib -rn <nn>                          # list libraries from dba_libraries (limit list to ROWNUM)
      obj -dict <partial name>                   # Display object whose name contain (partial string):
      obj -dir                                   # list object of type directory

      Display object name for user name   
      obj -u <USER> -t <TYPE> [TYPE: APPLY | CAPTURE | CLUSTER | CONSUMER GROUP | CONTEXT | DATABASE LINK | DIRECTORY |
                                        EVALUATION CONTEXT | FUNCTION | INDEX PARTITION | INDEX | INDEXTYPE | JAVA CLASS |
                                        JAVA DATA | JAVA RESOURCE | JOB CLASS | JOB | LIBRARY | LOB PARTITION | LOB | OPERATOR |
                                        PACKAGE BODY | PACKAGE | PROCEDURE | PROGRAM | QUEUE | RESOURCE PLAN | RULE SET | RULE |
                                        SCHEDULE | SEQUENCE | SYNONYM | TABLE PARTITION | TABLE | TRIGGER | TYPE BODY | TYPE |
                                        UNDEFINED | VIEW | WINDOW GROUP | WINDOW | XML SCHEMA
                 ie) obj -u sys -t "WINDOW GROUP"

     list object in cache per :
         obj -l   # sort by locks
         obj -p   # sort by pins
         obj -d   # sort by loads
         obj -e   # sort by executions

     Return the file_id and object number when only the relative DBA is given. typically given in a 10046
        obj -cdba d|h                        where 'd' when DBA is given in decimal and 'h' when given in hex
     "WAIT #5: nam='enq: HW - contention' ela= 55665 name|mode=1213661190 table space #=15 block=62915239 obj#=-1 tim=1172249513790845"
     ie : in 10046 we go the line :    obj -cdba 62915239 d

     
EOF
}

if [ -z "$1" ];then
   help
   exit
fi
typeset -u OBJ_NAME
while [ -n "$1" ]
do
  case "$1" in
     -cdba ) ACTION=CDBA ; CDBA=$2; TYPE=$3 ;shift;
             if [ -z "$2" ];then
                echo " I need a proper type (decimal|hexadecimal) for this DBA. Add 'd' or 'h'"
                exit
             else
               shift
             fi  ;;
        -b ) BLOCK_ID=$2 ; shift ; ACTION=${ACTION:-BLK};;
       -ff ) FILE_ID=$2  ; shift ; S_USER=SYS ; ACTION=BLK_FAST;;
      -dba ) BLOCK_ID="DBMS_UTILITY.DATA_BLOCK_ADDRESS_BLOCK($2)" ; shift ; ACTION=BLK;;
        -d ) ACTION=OBJ_CACHE SORT=" order by loads";;
     -dict ) OBJ_NAME=$2 ; shift; ACTION=DICT;;
      -dir ) ACTION=DIRECTORY  ;;
       -dt ) ORDER="6 desc";;
      -ddl ) ACTION=LIST_DDL ;;
     -dump ) ACTION=DUMP ;;
        -e ) ACTION=OBJ_CACHE SORT=" order by executions";;
        -f ) FILE_ID=$2  ; shift ; ACTION=${ACTION:-BLK};;
        -l ) ACTION=OBJ_CACHE SORT=" order by locks";;
      -lib ) ACTION=LIST_LIB ;;
        -n ) ACTION=OBJ_N; OBJN=$2 ; shift ;;
       -dn ) ACTION=OBJ_D; DATA_OBJN=$2 ; shift ;;
        -o ) ACTION=OBJ_NAME; ONAME=$2; shift ;;
    -oname ) ONAME=$2 ; shift ;;
        -p ) ACTION=OBJ_CACHE SORT=" order by pins";;
       -siz) ACTION=SIZE ; SEG=$2 ; shift ;;
        -t ) AND_OBJTYPE=" and object_type = upper('$2') "; shift ;;
      -tbs ) A_TBS=" and TABLESPACE_NAME='$2'" ; W_TBS=" where TABLESPACE_NAME='$2' "; shift;;
        -u ) if [ -z "$ACTION" ];then
                  ACTION=USER
             fi
             OWNER=$2; shift ;;
       -xt ) ACTION=NO_NEXT_EXT_SPACE;;
        -w ) OWNER=$2 ; shift ;;
        -v ) SETXV="set -xv" ;;
       -rn ) ROWNUM=$2 ; shift ;;
         * ) echo "??=$1" ;help ; exit ;;
  esac
  shift
done

SBINS=$SBIN/scripts
HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`


. $SBIN/scripts/passwd.env
. ${GET_PASSWD} $S_USER $ORACLE_SID

if [  "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi
$SETXV

if [ "$ACTION" = "LIST_LIB" ];then
   if [ -n "$OWNER" ];then
      WHERE_OWNER="where owner = upper('$OWNER')"
   fi
SQL="set lines 190 pagesize 66
col owner format a14
col LIBRARY_NAME format a25
col  FILE_SPEC format a80
col DYNAMIC format a7 head 'Dynamic'
col STATUS format a7
select * from (select OWNER,LIBRARY_NAME, DYNAMIC , STATUS, file_spec   from dba_libraries $WHERE_OWNER order by 1) 
  where rownum <= $ROWNUM;
"
elif [ "$ACTION" = "SIZE" ];then
SQL="
set linesize 132 pause off heading on
col ownr format a8      heading 'Owner'
col type format a18      heading 'Type'         
col name format a28     heading 'Segment Name'
col exid format     990 heading 'Extent#'      justify c
col fiid format   9,990 heading 'File#'        justify c
col blid format 9,999,990 heading 'Block#'       justify c
col blks format 9,999,990 heading 'Blocks'       justify c

break on ownr on name on type

select
  owner         ownr,
  segment_name  name,
  segment_type  type,
  extent_id     exid,
  file_id       fiid,
  block_id      blid,
  blocks        blks , bytes
from
  dba_extents
where
  owner like upper('$OWNER') and segment_name like upper('$SEG')
  order by owner, segment_name, extent_id
/

"
elif [ "$ACTION" = "DUMP" ];then
   if [ -z "$FILE_ID" ];then
      echo "I need a file id" ; exit
   fi
   if [ -z "BLOCK_ID" ];then
      echo "I need a block id" ; exit
   fi
  SQL="alter session set tracefile_identifier = 'dump_hb_${FILE_ID}_$BLOCK_ID' ;
alter system dump datafile $FILE_ID block $BLOCK_ID ;"

elif [ "$ACTION" = "LIST_DDL" ];then
   if [ "$OWNER" ];then
       AND_OWNER=" and owner=upper('$OWNER') " 
   fi
SQL="
set lines 150
select owner,object_type,name ,subname,status,
       to_char(last_ddl_time,'YYYY-MM-DD HH24:MI:SS') last_ddl_time
from (
    select  
         owner, object_type, object_name name, nvl(subobject_name,'-') subname ,
         status, last_ddl_time
    from dba_objects  
         where last_ddl_time is not null  $AND_OWNER order by last_ddl_time desc
) where rownum <= $ROWNUM;
"
elif [ "$ACTION" = "CDBA" ];then
   if [ ! "$TYPE" = 'd'  ];then
        if [ !   "$TYPE" = 'h' ];then
           echo " I need a proper type (decimal|hexadecimal) for this DBA. Add 'd' or 'h'"
           exit
       fi
   fi
SQL=" set serveroutput on size 99999
declare
x       NUMBER;
digits# NUMBER;
results NUMBER := 0;
file#   NUMBER := 0;
block#  NUMBER := 0;
cur_digit CHAR(1);
cur_digit# NUMBER;

BEGIN
      IF upper('$TYPE') = 'H' THEN
           digits# := length( '$CDBA' );
           FOR x  IN 1..digits#  LOOP
                cur_digit := upper(substr( '$CDBA', x, 1 ));
                IF cur_digit IN ('A','B','C','D','E','F')  THEN
                     cur_digit# := ascii( cur_digit ) - ascii('A') +10;
                ELSE
                     cur_digit# := to_number(cur_digit);
                END IF;
                results := (results *16) + cur_digit#;
           END LOOP;
      ELSE
           IF upper('$TYPE') = 'D' THEN
                results := to_number('$CDBA');
           ELSE
                dbms_output.put_line('H = Hex Input ... D = Decimal Input');
                RETURN;
                RETURN;
           END IF;
      END IF;
      file#  := dbms_utility.data_block_address_file(results);
      block# := dbms_utility.data_block_address_block(results);
      dbms_output.put_line('.');
      dbms_output.put_line( 'The file is ' || file# );
      dbms_output.put_line( 'The block is ' || block# );
END;
/
"

elif [ "$ACTION" = "NO_NEXT_EXT_SPACE" ];then
SQL="col owner format a18
col tablespace_name format a20
col header_file format 9999 head 'File|Id' justify c justify c
col next_extent heading 'Claimed|Next ext|size(k)' justify c
col bytes heading 'Bytes(k)'
select owner,segment_name,segment_type,header_file,bytes/1024 bytes,
  NEXT_EXTENT/1024 next_extent,tablespace_name from dba_segments
   where next_extent > ( select Max(Maxbytes - Bytes) From dba_data_files $W_TBS) $AT_TBS;
"
elif [ "$ACTION" = "USER" ];then
   if [ -n "$OWNER" ] ;then
      F_OWNER="and owner = upper('$OWNER')"
   fi
SQL="col object_name format a35
col object_type format a18
col status format a8
col subobject_name format a30
col last_ddl_time format a22
set linesize 132
break on object_type on report
select object_type,nvl(subobject_name,object_name) object_name ,status,
to_char(last_ddl_time,'DD-MM-YYYY HH24:MI:SS') last_ddl_time,
to_char(created,'DD-MM-YYYY HH24:MI:SS') created
from dba_objects where 1=1 $F_OWNER $AND_OBJTYPE order by 1,2;"

elif [ "$ACTION" = "DIRECTORY" ];then
SQL="
set lines 190
col DIRECTORY_PATH format a70
col OWNER format a20
col DIRECTORY_NAME format a30
select OWNER,DIRECTORY_NAME,DIRECTORY_PATH from dba_directories ;"
elif [ "$ACTION" = "NO_NEXT_EXT_SPACE" ];then
SQL="col owner format a18
col tablespace_name format a20
col header_file format 9999 head 'File|Id' justify c justify c
col next_extent heading 'Claimed|Next ext|size(k)' justify c
col bytes heading 'Bytes(k)'
select owner,segment_name,segment_type,header_file,bytes/1024 bytes,
NEXT_EXTENT/1024 next_extent,tablespace_name from dba_segments $A_TBS
   where next_extent > ( select Max(Maxbytes - Bytes) From dba_data_files $W_TBS);
"
# ----------------------------------------------------------------------
elif [ "$ACTION" = "OBJ_N" ];then
SQL="col object_name format a20
col object_type format a16
col status format a8
col subobject_name format a30
col last_ddl_time format a22
select owner,object_name,object_type,status,to_char(last_ddl_time,'DD-MM-YYYY HH24:MI:SS') last_ddl_time,subobject_name, data_object_id
from dba_objects where object_id = $OBJN;"


elif [ "$ACTION" = "DICT" ];then
SQL="select table_name from dict where table_name like '%$OBJ_NAME%';"

elif [ "$ACTION" = "OBJ_NAME" ];then
ORDER=${ORDER:-3}
SQL="
select owner, nvl(subobject_name,object_name) name, object_type, object_id , data_object_id,
        to_char(created,'YYYY-MM-DD HH24:MI:SS') created ,
        to_char(last_ddl_time,'YYYY-MM-DD HH24:MI:SS') last_ddl, status
        from dba_objects where object_name =  upper('$ONAME') order by $ORDER;"

elif [ "$ACTION" = "OBJ_D" ];then
ORDER=${ORDER:-3}
SQL="
select owner, nvl(subobject_name,object_name) name, object_type, object_id , data_object_id,
        to_char(created,'YYYY-MM-DD HH24:MI:SS') created ,
        to_char(last_ddl_time,'YYYY-MM-DD HH24:MI:SS') last_ddl, status
        from dba_objects where DATA_object_id =  $DATA_OBJN order by $ORDER;"

elif [ "$ACTION" = "OBJ_CACHE" ];then
SQL="select name,type , locks, pins,loads,executions from (
select owner||'.'||name name,type , locks, pins,loads,executions from v\$db_object_cache
$SORT desc ) where rownum < 25 ;
"
elif [ "$ACTION" = "BLK_FAST" ];then
SQL="col blocks format 99999
col file_id format 99999
col file_id format 99999
col ext_nr format 99999
col tablespace format a20
col sub_name format a20
col name format a20
col owner format a16
with subv as ( select u.name owner, o.name SEGMENT_NAME,
       o.subname partition_name, so.object_type,
       s.ts#,
       s.file# relative_fno,
       s.block# header_block
from sys.user$ u, sys.obj$ o,  sys.sys_objects so, sys.seg$ s
where s.file# = so.header_file
  and s.block# = so.header_block
  and s.ts# = so.ts_number
  and o.obj# = so.object_id
  and o.owner# = u.user#
  and s.type# = so.segment_type_id
  and o.type# = so.object_type_id
  and s.file# = $FILE_ID
order by s.block#
)
select * from (
      select ds.owner, ds.SEGMENT_NAME Name, ds.partition_name sub_name,
            ts.name tablespace,
            e.ktfbueblks blocks, e.ktfbuefno file_id,
            e.ktfbueextno ext_nr, e.ktfbuebno block_id
      from
           subv ds, sys.x\$ktfbue e, sys.ts$ ts
      where
             e.ktfbuesegfno = ds.relative_fno
         and e.ktfbuesegbno = ds.header_block
         and e.ktfbuesegtsn = ds.ts#
         and e.ktfbuefno = $FILE_ID
         and e.KTFBUEBNO > ($BLOCK_ID - ktfbueblks)
         and ts.ts# = ds.ts#
      order by KTFBUEBNO
) where rownum =1 ;
"

elif [ "$ACTION" = "BLK" ];then
SQL="select owner, segment_name, PARTITION_NAME,SEGMENT_TYPE,TABLESPACE_NAME, bytes/1048576 fs
   from dba_extents
            where  $FILE_ID = file_id and
                   $BLOCK_ID >= block_id and
                   $BLOCK_ID < block_id+blocks;
"

elif [ "$S_USER" = "SYS" -a   "$ACTION" = "FAST" ];then
# --------------------------------------------------------------
# This is fastest way to retrieve segment name given file and block id:
# Don chio
# Object name from file# and block#
# http://dioncho.wordpress.com/2009/07/06/object-name-from-file-and-block/
# Adapted to smenu by bpa, Jully 2007 
# --------------------------------------------------------------

VAR=`sqlplus -s "$CONNECT_STRING" <<EOF
set pause off head off verify off feed off termout off
alter system dump datafile $FILE_ID block $BLOCK_ID;
select (select value from v\\$parameter where name = 'user_dump_dest' )||'/'||lower(i.value)||'_ora_'||p.spid||'.trc'
  from v\\$process p, v\\$session s, 
             (select value from v\\$parameter where name = 'instance_name') i
  where p.addr = s.paddr
        and s.sid = (select sid from v\\$mystat where rownum = 1);
EOF`
TRC=`echo $VAR | tr -d '\n'`
     if [ ! -f "$TRC" ];then
        echo "I did not found the trace file"
        exit
     fi
     $SBINS/smenu_create_ext_table.ksh -f $TRC
     typeset -u fname30
     fpath=`dirname $TRC`                # full path name of the file
     fname=`basename $TRC`
     fname30=`echo $fname | cut -f1 -d'.'`
     fname30=`echo $fname30|cut -c1-30`             # trunc file name to max 30 characters
SQL="set serveroutput on
declare
      v_dba           varchar2(100);
      v_type          varchar2(100);
      v_cmd           varchar2(128);
      v_obj_id        number;
      v_obj_name      varchar2(100);
      cpt             number:=0;
      function to_dec ( p_str in varchar2, p_from_base in number default 16 ) return number
      is
             l_num   number default 0;
             l_hex   varchar2(16) default '0123456789ABCDEF';
      begin
             for i in 1 .. length(p_str) loop
		l_num := l_num * p_from_base + instr(l_hex,upper(substr(p_str,i,1)))-1;
	     end loop;
	     return l_num;
      end to_dec;
begin
	for r in (select fline  as t from $fname30 )
        loop
		if regexp_like(r.t, 'buffer tsn:') then
			dbms_output.put_line('------------------------------------------------');
			v_dba := regexp_substr(r.t, '[[:digit:]]+/[[:digit:]]+');
			dbms_output.put_line(rpad('dba = ',20)|| v_dba);
		end if;
		if regexp_like(r.t, 'type: 0x([[:xdigit:]]+)=([[:print:]]+)') then
			v_type := substr(regexp_substr(r.t, '=[[:print:]]+'), 2);
			dbms_output.put_line(rpad('type = ',20)|| v_type);
		end if;
		if regexp_like(r.t, 'seg/obj:') then
			v_obj_id := to_dec(substr(regexp_substr(r.t, 'seg/obj: 0x[[:xdigit:]]+'), 12));
			select object_name into v_obj_name from all_objects
				where data_object_id = v_obj_id;
			dbms_output.put_line(rpad('object_id = ',20)|| v_obj_id);
			dbms_output.put_line(rpad('object_name = ',20)|| v_obj_name);
		end if;
		if regexp_like(r.t, 'Objd: [[:digit:]]+') then
			v_obj_id := substr(regexp_substr(r.t, 'Objd: [[:digit:]]+'), 7);
			select object_name into v_obj_name from all_objects
				where data_object_id = v_obj_id;
			dbms_output.put_line(rpad('object_id = ',20)|| v_obj_id);
			dbms_output.put_line(rpad('object_name = ',20)|| v_obj_name);
		end if;
	end loop;
	dbms_output.put_line('------------------------------------------------');
        select count(1) into cpt from dba_external_locations 
               where table_name = upper('$fname30') and LOCATION='$fname' ;
        if cpt > 0 then
           v_cmd:='drop table $fname30';
           execute immediate v_cmd ;
        end if;
end;
/
"
fi

sqlplus -s "$CONNECT_STRING" <<EOF

ttitle skip 2 'MACHINE $HOST - ORACLE_SID : $ORACLE_SID '      'Page:' format 999 sql.pno skip 2

column nline newline
set pause off pagesize 66 linesize 80 embedded on termout on verify off
set head off
select 'Date              -  '||to_char(sysdate,'Day Ddth Month YYYY  HH24:MI:SS'),
       'Username          -  '||USER  || '     $TITTLE' from sys.dual
/
set linesize 160 head on
col owner format A20
col object_name format A30
col data_object_id format 999999999 head 'Data|object_id' justify c
col segment_name format A34
col PARTITION_NAME format A20
col TABLESPACE_NAME format A20
col SEGMENT_TYPE format A8 head "segment|type"
col fs format 999999 head "Size|(m)" justify C
col name format a35
$SQL
EOF

