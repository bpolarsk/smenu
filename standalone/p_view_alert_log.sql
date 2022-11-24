create or replace procedure p_view_alert_log ( p_row number  default 50 , p_and varchar2  ) 
is
 type tt is table of varchar2(1024) index by PLS_INTEGER ;
 v_tt tt;
begin
  if p_and = '-ora' then
     select  trim(record_id||':'||ldate||': '||line)  bulk collect into v_tt 
        from ( select record_id, ldate, line from 
                ( select  
                     record_id, to_char(originating_timestamp,'MON-DD HH24:MI:SS') ldate,
                     message_text line
            from x$dbgalertext where message_type in ( 2, 3 )  order by record_id desc
                )
          )
      where rownum <= p_row order by record_id ;
  else
      select  trim(record_id||':'||ldate||': '||line)  bulk collect into v_tt 
         from ( select record_id, ldate, line from 
                ( select  
                     record_id, to_char(originating_timestamp,'MON-DD HH24:MI:SS') ldate,
                     message_text line
            from x$dbgalertext order by record_id desc
                )
          )
      where rownum <= p_row order by record_id ;
  end if  ;
  for i in 1..v_tt.count
  loop
    dbms_output.put_line(regexp_replace(v_tt(i),chr(10),'') ) ;
  end loop ;
end ;
/

show errors ;

grant execute on sys.p_view_alert_log to p0957 ;
grant execute on sys.p_view_alert_log to p8169 ;
grant execute on sys.p_view_alert_log to p0925 ;

exit
