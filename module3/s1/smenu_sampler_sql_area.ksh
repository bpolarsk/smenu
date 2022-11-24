#!/bin/sh
# author Bernard polarski
#set -xv


while [ -n "$1" ]
do
  case "$1" in
    -i ) INTERVAL=$2      ; shift ;;
    -d ) SAMPLER_DIR=$2   ; shift ;;
    -l ) DURATION_SEC=$2  ; shift ;;
  esac
  shift
done
# this one must always have a value
DURATION_SEC=${DURATION_SEC:-0}
INTERVAL=${INTERVAL:-5}
cd $SAMPLER_DIR

FDATE=`date +%Y%m%d%H%M%S`
FOUT=$SAMPLER_DIR/sample_txt_w_{$ORACLE_SID}.${FDATE}
SCRIPT=$SAMPLER_DIR/sampler_txt_w_${ORACLE_SID}.ksh

S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [ "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# create the semaphore to stop the process when needed
cat > $SCRIPT <<EFI
#!/bin/sh

sqlplus -s "$CONNECT_STRING" <<EOF
create directory SAMPLER_W_DIR as '$SAMPLER_DIR' ;
create global temporary table tbl_hv ( HASH_VALUE NUMBER) on commit preserve rows;
insert into tbl_hv select hash_value from v\\\$sqltext ;
commit ;
select count(1) from tbl_hv;
declare
  file_id1  UTL_FILE.FILE_TYPE ;
  max_len   integer ;
  curr_len  integer ;
begin
  curr_len:=0 ;
  if ( $DURATION_SEC > 0 )then
    max_len:=$DURATION_SEC;
  end if;
  file_id1:=utl_file.fopen('SAMPLER_W_DIR','sample_txt_w_${ORACLE_SID}$FDATE.txt','a',256);
  for r in (select hash_value from tbl_hv)
  LOOP 
      for p in ( select to_char(hash_value) hv, to_char(piece) pi, sql_text st from v\\\$sqltext 
               where hash_value=r.hash_value order by piece)
        LOOP
           utl_file.put_line(file_id1,p.hv||'{'||p.pi||'{'||p.st);
        END LOOP;
  END LOOP;
  utl_file.fflush(file_id1);

  LOOP
     for r in ( select a.hash_value from v\\\$sqltext a left join tbl_hv t on
             a.hash_value = t.hash_value where t.hash_value = null )
     LOOP
 
       for p in ( select to_char(hash_value) hv, to_char(piece) pi, sql_text st from v\\\$sqltext 
                   where hash_value=r.hash_value order by piece)
          LOOP
            utl_file.put_line(file_id1,p.hv||'{'||p.pi||'{'||p.st);
          END LOOP;
     END LOOP;
     utl_file.fflush(file_id1);
     dbms_lock.sleep($INTERVAL);
     if ( $DURATION_SEC > 0 )then
          curr_len:=curr_len+$INTERVAL ;
          if ( curr_len > max_len )then
             exit ;
          end if;
     end if ;
 END LOOP ;

 utl_file.fclose(file_id1);
 EXCEPTION
     WHEN utl_file.invalid_path THEN
         RAISE_APPLICATION_ERROR(-20001, 'utl_file.invalid_path');
     WHEN utl_file.invalid_mode THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.invalid_mode');
     WHEN utl_file.invalid_filehandle THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.invalid_filehandle');
     WHEN utl_file.invalid_operation THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.invalid_operation');
     WHEN utl_file.read_error THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.read_error');
     WHEN utl_file.write_error THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.write_error');
     WHEN utl_file.internal_error THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.internal_error');
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20001, 'utl_file.other_error');   
end ;
/
EOF

EFI

echo "$SCRIPT"
chmod 755 $SCRIPT
echo "You can now type : 

          cd $SAMPLER_DIR
          nohup $SCRIPT &" 
     #for r in (select hash_value hv from v\\\$sqltext)
     #LOOP
     #   utl_file.put_line(file_id1, r.hv);
     #   utl_file.fflush(file_id1);
     #END LOOP ;
