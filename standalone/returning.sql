set serveroutput on size unlimited
create table emp_test (
          empno number,
          empname varchar2(30),
          sales     number
        );
Declare
 TYPE TYP_TAB_EMPNO IS TABLE OF EMP_TEST.EMPNO%Type ;
 TYPE TYP_TAB_NOM IS TABLE OF EMP_TEST.EMPNAME%Type ;
 TYPE TYP_TAB_SALE IS TABLE OF EMP_TEST.SALES%Type ;
 tab_empno TYP_TAB_EMPNO ;
 tab_empname TYP_TAB_NOM ;
 tab_sale TYP_TAB_SALE ;
 v_cpt number ;
Begin
    -- file the table
    insert into emp_test  select level empno, dbms_random.string('a',30) name, trunc(dbms_random.value(1,1000)) sales from dual connect by level < 1000;
    commit ;

   dbms_output.put_line('Virons tous les employéqui ont vendu pour moins de 300 roroo:');
   Delete From EMP_TEST where sales < 300
          RETURNING empno, empname, sales BULK COLLECT INTO tab_empno, tab_empname , tab_sale;
    commit ;
    If tab_empno.first is not null Then
        For i in tab_empno.first..tab_empno.last Loop
            dbms_output.put_line( 'Employee' || To_char( tab_empno(i) ) || ' ' || tab_empname(i) ||
                ' qui n''a vendu que pour ' ||to_char(tab_sale(i) )|| ' est vire') ;
        End loop ;
    End if ;
    select count(*) into v_cpt from emp_test ;
    dbms_output.put_line('Ne reste plus que ' || to_char(v_cpt) ||  ' employes' ) ;
End ;
/
drop table emp_test;


