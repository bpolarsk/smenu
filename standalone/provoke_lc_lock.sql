create or replace procedure test_kgllk (l_sleep in boolean , l_compile in boolean)
as
 begin
  if (l_sleep ) then
	sys.dbms_lock.sleep(60);
  elsif (l_compile )  then
  	execute immediate 'alter procedure test_kgllk compile';
  end if;
 end;
/

-- create two sessions in the database and then execute them as below. 

-- Session #1: exec test_kgllk ( true, false); . Sleep for 1 minutes and no compile
-- Session #2: exec test_kgllk ( false, true); . No sleep,but compile.. 


