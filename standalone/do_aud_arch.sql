CREATE OR REPLACE PACKAGE SYS.DO_AUD_ARCH AS
Begin
   procedure do_trf_daily ;
end ;
/

CREATE OR REPLACE
PACKAGE BODY SYS.DO_AUD_ARCH AS

  procedure do_trf_daily  AS
  BEGIN
    --  
    insert into system.aud_arch select * from sys.aud$ where ntimestamp# < trunc(sysdate) ;
    delete from sys.aud$ where ntimestamp# < trunc(sysdate) ;
    commit ;
  END do_trf_daily;

  

END DO_AUD_ARCH;
