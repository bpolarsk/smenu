--variable myspid number ;
--variable udump varchar2(512) ;

set head off
col spid new_value myspid noprint
col val new_value udump noprint 
col instance_name new_value inst noprint 
select spid  from v$process where addr = ( select paddr from v$session where sid = (select sid from v$mystat where rownum = 1));
select value val from v$parameter where name = 'user_dump_dest' ;
select lower(instance_name) instance_name  from v$instance ;
host mknod &udump./&&inst._ora_&&myspid..trc  p;
set define ?
host grep "WAIT" ??udump./??inst._ora_??myspid..trc &
set define &
alter session set events '10046 trace name context forever, level 8';
