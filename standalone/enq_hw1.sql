-- Script enq_hw1.sql -----------
variable v_begin_cnt number
variable v_end_cnt number

prompt
prompt  Tablespace: Locally managed with \&1
prompt
drop tablespace TS_LMT_HW including contents and datafiles;

create tablespace TS_LMT_HW datafile '/oradb01/oracle/oradata/WLINT21/test_01.dbf'
 size 500M extent management local &1;

create table test_hw (n1 number ,  c1 clob )     tablespace TS_LMT_HW;

begin
  select total_req# into :v_begin_cnt from v$enqueue_statistics where 	eq_type ='HW';
end;
/
insert into test_hw
 select n, lpad(n, 4000,'a') v1 from
   (select level n from dual connect by level <10000);
commit;
select total_req#, succ_req#, failed_req# from v$enqueue_statistics where 	eq_type ='HW';

begin
  select total_req# into :v_end_cnt from v$enqueue_statistics where 	eq_type ='HW';
end;
/

select :v_end_cnt - :v_begin_cnt diff from dual;

--- script end enq_hw1.sql -----------

