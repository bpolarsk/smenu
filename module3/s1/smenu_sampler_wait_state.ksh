#!/bin/sh
# author Bernard polarski
set -xv


while [ -n "$1" ]
do
  case "$1" in
    -i ) INTERVAL=$2      ; shift ;;
    -d ) SAMPLER_DIR=$2   ; shift ;;
    -l ) DURATION_SEC=$2  ; shift ;;
    -s ) INTERVAL_SQL=$2  ; shift ;;
    -o ) ORADIR=$2 ; shift ;;
   -x ) EXEC_IMMEDIATE=YES ;;
  esac
  shift
done
# this one must always have a value
DURATION_SEC=${DURATION_SEC:-0}
INTERVAL_WAIT=${INTERVAL:-1}
INTERVAL_SQL=${INTERVAL_SQL:-60}
cd $SAMPLER_DIR

FDATE=`date +%Y%m%d%H%M%S`
FOUT=$SAMPLER_DIR/sample_w_{$ORACLE_SID}.${FDATE}
SCRIPT=$SAMPLER_DIR/sampler_w_${ORACLE_SID}.ksh

S_USER=SYS
. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [ "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# create the semaphore to stop the process when needed
echo 'run' > $SAMPLER_DIR/sem_w_${ORACLE_SID}.txt
cat > $SCRIPT <<EFI
#!/bin/sh

sqlplus -s "$CONNECT_STRING" <<EOF
create directory $ORADIR as '$SAMPLER_DIR' ;
declare
  DDATE    varchar2(14);
  buffer   varchar2(6);
  file_id1  UTL_FILE.FILE_TYPE ;
  file_id2 UTL_FILE.FILE_TYPE ;
  i        integer ;
  cpt      integer ;
  n        integer ;
  max_len  integer ;
  curr_len integer ;
  bol             boolean ;
  f_sem_size      number ;
  f_sem_blk       number ;
begin
  cpt:=0;
  curr_len:=0 ;
  n:=10/$INTERVAL;
  if ( $DURATION_SEC > 0 )then
    max_len:=$DURATION_SEC/$INTERVAL;
  end if;
  file_id1:=utl_file.fopen('$ORADIR','sample_w_${ORACLE_SID}$FDATE.txt','a',256);
  utl_file.fgetattr('$ORADIR','sem_w_${ORACLE_SID}.txt',BOL ,f_sem_size, f_sem_blk);
  if ( f_sem_size > 0 ) then
        file_id2:=utl_file.fopen('$ORADIR','sem_w_${ORACLE_SID}.txt','r',81);
  end if; 
  LOOP
     select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
     for r in (select to_char(SID) sid,to_char(SEQ#) seq#, event#, EVENT, 
                       to_char(WAIT_TIME) wt, to_char(SECONDS_IN_WAIT) siw, 
                       to_char(p1) p1, to_char(rawtohex(p1raw)) p1r, p1text,
                       to_char(p2) p2, to_char(rawtohex(p1raw)) p2r, p2text,
                       to_char(p3) p3, p3text
                from v\\\$session_wait , v\\\$event_name n
                     where event = name                           and
                           event != 'pmon timer'                  and 
                           event != 'rdbms ipc message'           and
                           event != 'PL/SQL lock timer'           and
                           event != 'SQL*Net message from client' and
                           event != 'smon timer' )
     LOOP
        utl_file.put_line(file_id1, DDATE||'{'||r.sid|| '{' || r.seq#|| '{' || r.event# || '{' ||
                          r.event || '{' || r.wt ||'{'||r.siw||'{'||r.p1||'{'||r.p1r||'{'||r.p1text||'{'
                          ||r.p2||'{'||r.p2r||'{'||r.p2text||'{'||r.p3 ||'{'||r.p3text) ;
        utl_file.fflush(file_id1);
     END LOOP ;
     dbms_lock.sleep($INTERVAL);
     cpt:=cpt+1 ;
     if (cpt > n ) then
        cpt:=0 ;
        if ( f_sem_size > 0 ) then
           utl_file.fseek(file_id2,0,NULL);
           utl_file.get_line(file_id2,buffer,81);
           if (buffer != 'run' ) then
             exit ;
           end if;
        end if;
     end if;
     if ( $DURATION_SEC > 0 )then
          curr_len:=curr_len+$INTERVAL ;
          if ( curr_len > max_len )then
             exit ;
          end if;    
     end if ;
 END LOOP ;
 if ( f_sem_size > 0 ) then
      utl_file.fclose(file_id2);
 end if ;
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
if [ "$EXEC_IMMEDIATE" = "YES" ];then
   cd $SAMPLER_DIR
   nohup $SCRIPT &
   echo "Sampler started for waits alone"
else
echo "You can now type :

          cd $SAMPLER_DIR
          nohup $SCRIPT &"
fi
