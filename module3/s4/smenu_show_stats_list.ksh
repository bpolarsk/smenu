#!/bin/sh
#set -xv
#-------------------------------------------------------------------------------
#-- Script 	smenu_statpack.sh
#-- Purpose 	
#-- For:		All versions
#-- Author 	Bpolarsk
#-- Date        23-Jan-2001      : Creation
#-- Description: This script rely on the statspack found in ./rdbms/admin
#__ adapted to smenu by B. Polarski
#-------------------------------------------------------------------------------

HOST=`hostname`
HOST=`echo $HOST | awk '{ printf ("%-+15.15s",$1)  }'`
THE_ORACLE_SID=`echo $ORACLE_SID | awk '{printf ("%-15.15s",$1)}'`
SBINS=$SBIN/scripts


if [ "x-$ORACLE_SID" = "x-" ];then
   echo "Oracle SID is not defined .. aborting "
   exit 0
fi
var=$ORACLE_SID:perfstat
grep $var $SBIN/scripts/.passwd > /dev/null
if [ $? -eq 0 ];then
   S_USER=perfstat 
   . $SBIN/scripts/passwd.env
   . ${GET_PASSWD} $S_USER $ORACLE_SID
else
   CONNECT_STRING=perfstat/perfstat
fi
  
sqlplus -s "$CONNECT_STRING" <<EOF

set feed off head off termout off verify off
set termout on feed on head on;
set linesize 124 pagesize 66
--
--  List Snapshots

column inst_num  heading "Inst Num"  new_value inst_num  format 99999;
column inst_name heading "Instance|Name"  new_value inst_name format a10;
column db_name   heading "DB Name"   new_value db_name   format a10;
column dbid      heading "DB Id"     new_value dbid      format 9999999999 just c;
select d.dbid            dbid
     , d.name            db_name
     , i.instance_number inst_num
     , i.instance_name   inst_name
  from v\$database d,
       v\$instance i;

variable dbid       number;
variable inst_num   number;
variable inst_name  varchar2(20);
variable db_name    varchar2(20);
begin
  :dbid      :=  &dbid;
  :inst_num  :=  &inst_num;
  :inst_name := '&inst_name';
  :db_name   := '&db_name';
end;
/


column snap_id       format 9999990 heading 'Snap Id'
column snap_date     format a21   heading 'Snapshot Started'
column host_name     format a15   heading 'Host'
column parallel      format a3    heading 'OPS' trunc
column level         format 99    heading 'Snap|Level'
column versn         format a7    heading 'Release'
column ucomment          heading 'Comment' format a25;

prompt
prompt
prompt Snapshots for this database instance
prompt ====================================

select s.snap_id
     , s.snap_level                                      "level"
     , to_char(s.snap_time,' dd Mon YYYY HH24:mi:ss')    snap_date
     , di.host_name                                      host_name
     , s.ucomment
  from stats\$snapshot s
     , stats\$database_instance di
 where s.dbid              = :dbid
   and di.dbid             = :dbid
   and s.instance_number   = :inst_num
   and di.instance_number  = :inst_num
   and di.startup_time     = s.startup_time
 order by db_name, instance_name, snap_id
/

EOF
