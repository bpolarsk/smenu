drop table cousin;
drop table child ;
drop table parent ;
create table parent ( pk_par number,
                      par_data varchar2(20)) ;
alter table parent add primary key (pk_par) ;

create table child (pk_child number,
                    child_data varchar2(200),
                    col3p number ,
                    col3c number );
alter table child add primary key (pk_child);

create table cousin (pk_cousin number,
                    cousin_data varchar2(20) ,
                    col4 number not null);
alter table cousin add primary key (pk_cousin);


insert into parent values (1,'row1');
insert into parent values (2,'row1');
insert into parent values (3,'row1');
insert into parent values (4,'row1');
insert into parent values (5,'row1');
insert into parent values (6,'row1');
set timing on
-- let's create some million rows
-- split the work or you may get not enough memory
insert into child values (1,'child 1', 1, 1 ) ;
commit ;
set serveroutput on size unlimited
declare 
 v_cpt number;
begin
for i in 1..200
  loop
   dbms_output.put_line('loop='||to_char(i) ) ;
     select max(pk_child) into v_cpt from child ;
     insert into child select level + v_cpt, 'child '|| to_Char(level+v_cpt) || ' qsdmlfqmsdfmqlsdkfmqmsdfkmqsdfkmqsdkfmqksdmfmqskdfmq', 1, 1 from dual connect by level <100000 ; 
     commit;
  end loop;
end; 
/

insert into cousin values(1,' cousin 2', 1 );
insert into cousin values(2,' cousin 2', 2 );
insert into cousin values(3,' cousin 3', 3 );
insert into cousin values(4,' cousin 4', 4 );
insert into cousin values(5,' cousin 5', 5 );
insert into cousin values(6,' cousin 6', 6 );
insert into cousin values(7,' cousin 7', 7 );


alter table child add constraint FK_to_parent foreign key (col3p) references parent(pk_par);
alter table child add constraint FK_to_cousin foreign key (col3c) references cousin(pk_cousin);
-- alter table cousin add constraint FK_to_child foreign key (col4) references child(pk_child);


commit ;

set pages 66 lines 190
 select * from parent;
 select * from cousin ;
 select count(*) from child ;




