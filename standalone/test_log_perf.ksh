#!/bin/sh
NBR_LOG=${1:-10}
NBR_PASS=10
CONNECT_STRING="/ as sysdba"
sqlplus -s "$CONNECT_STRING" <<EOF
alter system switch logfile ;
set lines 190
set serveroutput on size unlimited
declare
i number;
SQL_CMD varchar2(4000);
begin 
 select count(*) into i from dba_tables where table_name = 'T1' and owner = 'SYS' ;
 dbms_output.put_line ('i='||to_char(i));
   if ( i = 0 ) 
   then
       begin
       dbms_output.put_line ('Creating table T1' );
       SQL_CMD:='create table T1 as select * from dba_source where 1 = 2 ';
       execute immediate SQL_CMD ;
       exception when others then
            dbms_output.put_line ('could not create table T1' );
            return ;
       end ;
   else 
     dbms_output.put_line ('table T1 already exist');
   end if ; 
end ;
/
declare

type rrec is record (rtype varchar2(5), name varchar2(64), index# number, value number );
type trec is table of rrec index by pls_integer;
s1 trec;
s2 trec;
a number;
b number;
i number;
SQL_CMD varchar2(4000);
delta number;
v_logpar number;
first_time timestamp ;
second_time timestamp ;
   -----------------------------------------
   procedure output(p_txt in varchar2) is
   begin
        dbms_output.put_line(p_txt);
   end ;
   -----------------------------------------
   procedure get_measure (v_time in out timestamp , v_trec in out trec ) is
   begin
       v_time:=systimestamp ;
       -- select * bulk collect into v_trec from (
       --       select name ,STATISTIC# index#, value from v\$sysstat where name = ('redo write time')
       --       union
       --       select e.name, e.event# +1000 as index#, s.time_waited_micro/10000 value from v\$event_name e, v\$system_event s
       --              where  name like '%log file%' and e.event_id = s.event_id
       select * bulk collect into v_trec from (
             select 'STAT' ,name ,STATISTIC# index#, value from v\$sysstat 
             union all
             select 'EVENT', e.name, e.event# +1000 as index#, s.time_waited_micro/10000 value from v\$event_name e, v\$system_event s
                    where  e.event_id = s.event_id
             union all
             select 'LATCH', n.name, l.latch# + 5000 as index# , l.gets + l.immediate_gets value
                                         from v\$latch l, v\$latchname n where n.latch# = l.latch#
       ) ;
   end ;
   -----------------------------------------
   procedure do_job
   is
  
   begin
     for c1 in (select OWNER,NAME, TYPE, LINE, TEXT  from dba_source)
     loop
        insert into t1 values (c1.owner, c1.name,c1.type,c1.line,c1.text);
        commit ;
     end loop ;
   end ;
   -----------------------------------------

------ Main ----------
begin

  -- test if T1 table exists 
 select MEMBERS into i from v\$log where GROUP#  = 1 and THREAD# = 1 ;
 output('Members for log group 1 thread 1 : ' || to_char(i)) ;
   
   get_measure (first_time,s1) ;
   do_job ;
   get_measure (second_time,s2);
   output ('sample duration : ' || to_char(second_time-first_time)) ;
      a :=1; -- s1 array index
      b :=1; -- s2 array index

    while ( a <= s1.count and b <= s2.count ) loop
    case
       when s1(a).index# = s2(b).index# then
             delta := s2(b).value - s1(a).value;
             if delta > 0 then
                if (s2(b).index# = 106 )    -- log_file_parallel write
                then
                   v_logpar:=delta;
                end if ;
               if ( s2(b).index# = 140 ) then 
                   output  (rpad(s2(b).rtype,6,' ') ||'  '|| rpad(s1(a).name , 64, ' ') || to_char(delta) || '   '||to_char(delta -v_logpar || 
                           'cs   '||substr(to_char((delta-v_logpar)/delta*100),1,5) || '%' )) ;
               else
                   output  (rpad(s2(b).rtype,6,' ') ||'  '|| rpad(s1(a).name , 64, ' ') || to_char(delta) ) ;
               end if ;
             end if ;
             a := a + 1;
             b := b + 1;

       when s1(a).index# < s2(b).index# then
             output (rpad(s1(a).name , 64, ' ') || to_char(s1(a).value) ) ;
              a := a + 1;
             
       else
                    output('Err for ' ||s2(b).name );
    end case; 
    end loop ;
    
    -- optional 
   SQL_CMD:='drop table t1';
   execute immediate SQL_CMD ;


end;
/
EOF
