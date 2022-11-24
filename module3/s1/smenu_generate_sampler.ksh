#!/bin/sh
# date       : 11 November 2005
# author     : Bernard polarski
# program    : smenu_generate_sampler.ksh
#              Sampler over the Oracle Wait Interface
#              This program dump all sample data from different views using different time frame.
#              His driving interface is 'spl' (sm/3.1) and reporting is also done through 'spl' with parameters
#              Use this to determine where Your DB is waiting, which sql and why
# set -x
SAMPLER_DIR=$SBIN/tmp
EXEC_IMMEDIATE=NO 
DELTA=0
while [ -n "$1" ]
do
  case "$1" in
    -i ) INTERVAL_WAIT=$2      ; shift ;;
    -d ) SAMPLER_DIR=$2   ; shift ;;
    -l ) DURATION_SEC=$2  ; shift ;;
    -x ) EXEC_IMMEDIATE=YES ;;
    -p ) PASSWD=$2 ; shift ;;
    -u ) F_USER=$2 ; shift ;;
    -o ) SID=$2 ; shift  ;;
 -perl ) DO_PERL=TRUE ;;
    -s ) INTERVAL_DELTA=$2 ; shift ;;
  esac
  shift
done
# this one must always have a value
DURATION_SEC=${DURATION_SEC:-1800}
INTERVAL_WAIT=${INTERVAL_WAIT:-1}
INTERVAL_DELTA=${INTERVAL_DELTA:-60}
cd $SAMPLER_DIR
S_USER=SYS
if [ -n "$DO_PERL" ];then
   SID=${SID:-$ORACLE_SID}
   if [ -z "$F_USER" ];then
      if [ -f $SMENU/data/smenu_default_user.txt ];then
           F_USER=`grep -i "^$SID:" | cut -f2 -d':'`
           if [ -z "$FUSER" ];then
                F_USER=$S_USER
           fi
       else
           F_USER=$S_USER
 
       fi
   fi
   if [ -z "$PASSWD" ];then
        PASSWD=`grep -i "^$SID:$F_USER:" $SBIN/scripts/.passwd| cut -f3 -d':'| cut -f1 -d'@'` 
        if [ -z "$PASSWD" ];then
           echo "No passwd given or found for user $F_USER for sid $SID"
           exit 0
        fi
   fi
   echo 'run' > $SAMPLER_DIR/sem_sql_w_${SID}.txt
   nohup perl $SBIN/module3/s1/smenu_sampler_wait_perl.pl  -d $SAMPLER_DIR -l  $DURATION_SEC -i $INTERVAL_WAIT -s $INTERVAL_DELTA -o $SID -u $F_USER -p $PASSWD  2>&1 &
   exit
fi

OS=`uname|cut -c1-3`
if [ "$OS" = "CYG" ];then
   SAMPLER_DIR=`echo $SAMPLER_DIR | sed 's@/@\\\\@g'`
fi

FDATE=`date +%d%m%H%M`
FOUT=$SAMPLER_DIR/sample_sql_w_{$ORACLE_SID}.${FDATE}
SCRIPT=$SAMPLER_DIR/sampler_sql_w_${ORACLE_SID}.ksh

. $SBIN/scripts/passwd.env
. ${GET_PASSWD} SYS $ORACLE_SID
if [ "x-$CONNECT_STRING" = "x-" ];then
   echo "could no get a the password of $S_USER"
   exit 0
fi

# create the semaphore to stop the process when needed
ret0=`sqlplus -s "$CONNECT_STRING" <<EOF
set head off pagesize 0 pause off
select count(1) from dba_tables where table_name = 'TBL_HV';
EOF`
ret=`echo $ret0 | awk '{print $1}'`

# create a semaphore file to allow clean stop of process
echo 'run' > $SAMPLER_DIR/sem_sql_w_${ORACLE_SID}.txt

cat > $SCRIPT <<EFI
#!/bin/sh

   sqlplus -s "$CONNECT_STRING" <<EOF
EFI

if [ $ret -lt 1 ];then
  echo "create global temporary table tbl_hv (SQL_ID VARCHAR2(13)) on commit preserve rows;" >> $SCRIPT
else
  echo "drop table tbl_hv;" >> $SCRIPT
  echo "create global temporary table tbl_hv (SQL_ID VARCHAR2(13)) on commit preserve rows;" >> $SCRIPT
 
fi
cat >> $SCRIPT <<EFI
insert into tbl_hv select distinct sql_id from v\\\$sqltext ;
commit ;
select count(1) from tbl_hv;
create directory SAMPLER_W_DIR as '$SAMPLER_DIR' ;
declare
  DDATE                  varchar2(14);
  buffer                 varchar2(6);
  fp1                    UTL_FILE.FILE_TYPE ;
  fp2                    UTL_FILE.FILE_TYPE ;
  fp3                    UTL_FILE.FILE_TYPE ;
  fp4                    UTL_FILE.FILE_TYPE ;
  fp5                    UTL_FILE.FILE_TYPE ;
  fp6                    UTL_FILE.FILE_TYPE ;
  delta_curr_interval    integer ;
  delta_max_interval     integer ;
  delta                  integer ;
  max_len                integer ;
  curr_len               integer ;
  f_sem_size             number ;
  f_sem_blk              number ;
  BOL                    boolean ;
begin
  delta_max_interval:=$INTERVAL_DELTA;
  delta_curr_interval:=0;
  curr_len:=0 ;
  delta:=$DELTA ;
  if ( $DURATION_SEC > 0 )then
    max_len:=$DURATION_SEC;
  end if;

  utl_file.fgetattr('SAMPLER_W_DIR','sem_sql_w_${ORACLE_SID}.txt',BOL ,f_sem_size, f_sem_blk);
  if ( f_sem_size > 0 ) then
        fp2:=utl_file.fopen('SAMPLER_W_DIR','sem_sql_w_${ORACLE_SID}.txt','r',81);
  end if; 
  /* -----------------------------------------------------------------------------------------*/
  /* at start, we dump the text of SQL reading the list of he sql_id from tbl_hv  */
  /* -----------------------------------------------------------------------------------------*/
  fp3:=utl_file.fopen('SAMPLER_W_DIR','sample_txt_w_${ORACLE_SID}.$FDATE','a',256);
  for r in (select sql_id from tbl_hv)
  LOOP
      for p in ( select sql_id hv, to_char(piece) pi, sql_text st from v\\\$sqltext
               where sql_id=r.sql_id order by piece)
        LOOP
           utl_file.put_line(fp3,p.hv||'{'||p.pi||'{'||p.st);
        END LOOP;
  END LOOP;
  utl_file.fflush(fp3);
  /* -----------------------------------------------------------------------------------------*/
  /* For delta, it is required that we dump v$sql and v$sysstat, v$session_event              */
 /*  before the main loop. It will be dumped again every time delta_curr_interval elapses     */
  /* -----------------------------------------------------------------------------------------*/

  /* ............. Write V$SQL ............... */
  fp4:=utl_file.fopen('SAMPLER_W_DIR','sample_delta_w_${ORACLE_SID}.$FDATE','a',256);
  select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 

  for d in (select SQL_ID hv, to_char(ROWS_PROCESSED) rp,to_char(DISK_READS) dr,
                      to_char(FETCHES) fe, to_char(EXECUTIONS) ex, to_char(loads) lo,
                      to_char(PARSE_CALLS) pa, to_char(BUFFER_GETS) bg, to_char(SORTS) so,
                      to_char(CPU_TIME) ct, FIRST_LOAD_TIME fl, to_char(PLAN_HASH_VALUE) phv,
                      to_char(child_number) chn, module md from v\\\$sql )
  LOOP
           utl_file.put_line(fp4, DDATE|| '{' || d.hv|| '{' || d.rp || '{' || d.dr|| '{'||d.fe || '{' || 
                      d.ex ||'{' || d.lo || '{' || d.pa || '{' || d.bg || '{' || d.so || '{' || d.ct || 
                      '{' || d.fl || '{' || d.phv || '{' || d.chn || '{' || d.md );
  END LOOP ;
  utl_file.fflush(fp4);

  /* ............. Write V$SYSTAT ........... */
  fp5:=utl_file.fopen('SAMPLER_W_DIR','sample_sys_w_${ORACLE_SID}.$FDATE','a',256);
  select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
  for d in (select to_char(STATISTIC#) stn, name,to_char(value) value from v\\\$sysstat )
  LOOP
  utl_file.put_line(fp5,DDATE||'{'||d.stn||'{'||d.name||'{'||d.value );
  END LOOP;
  utl_file.fflush(fp5);

  /* ............. Write V$SESSION_EVENT ........... */
  fp6:=utl_file.fopen('SAMPLER_W_DIR','sample_evt_w_${ORACLE_SID}.$FDATE','a',256);
  select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
  for d in (select to_char(a.sid) sid,to_char(b.serial#) serial,a.EVENT, to_char(a.TOTAL_WAITS) TOTAL_WAITS,
                   to_char(a.TOTAL_TIMEOUTS) TOTAL_TIMEOUTS, to_char(a.TIME_WAITED) TIME_WAITED, 
                   to_char(a.AVERAGE_WAIT) AVERAGE_WAIT, to_char(a.MAX_WAIT) MAX_WAIT,
                   to_char(a.TIME_WAITED_MICRO) TIME_WAITED_MICRO,b.program,b.module,b.action,b.username
               from v\\\$session_event a, v\\\$session b where a.sid=b.sid)
  LOOP
  utl_file.put_line(fp6,DDATE||'{'||d.sid || '{'|| d.serial  || '{'|| d.event  || '{'|| d.total_waits ||'{'|| 
                        d.total_timeouts ||'{'||d.time_waited ||'{'|| d.average_wait ||'{'|| d.max_wait||'{'|| 
                        d.time_waited_micro||'{'|| d.program||'{'||d.module||'{'|| d.action ||'{'||d.username);
  END LOOP;
  utl_file.fflush(fp6);

  fp1:=utl_file.fopen('SAMPLER_W_DIR','sample_sql_w_${ORACLE_SID}.$FDATE','a',256);

  /* -----------------------------------------------------------------------------------------*/
  /*                   Main loop                                                              */
  /* -----------------------------------------------------------------------------------------*/
  LOOP
     select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
     for r in (select to_char(w.SID) sid,to_char(w.SEQ#) seq#, n.event#, w.EVENT, 
                       to_char(w.WAIT_TIME) wt, to_char(w.SECONDS_IN_WAIT) siw, 
                       to_char(w.p1) p1, to_char(rawtohex(w.p1raw)) p1r, w.p1text,
                       to_char(w.p2) p2, to_char(rawtohex(w.p1raw)) p2r, w.p2text,
                       to_char(w.p3) p3, w.p3text, to_char(s.sql_id)shv,to_char(prev_sql_id)phv,
                       to_char(ROW_WAIT_OBJ#) rwo
                from v\\\$session_wait w, v\\\$session s, v\\\$event_name n
                     where w.sid = s.sid (+)                      and
                           w.event = n.name                       and
                           w.event != 'pmon timer'                  and 
                           w.event != 'rdbms ipc message'           and
                           w.event != 'PL/SQL lock timer'           and
                           w.event != 'SQL*Net message from client' and
                           w.event != 'client message'              and
                           w.event != 'pipe get'                    and
                           w.event != 'Null event'                  and
                           w.event != 'wakeup time manager'         and
                           w.event != 'slave wait'                  and
                           w.event != 'Streams AQ: qmn coordinator idle wait' and
                           w.event != 'DIAG idle wait' and
                           w.event != 'VKTM Logical Idle Wait' and
                           w.event != 'Space Manager: slave idle wait'and
                           w.event != 'jobq slave wait'            and
                           w.event != 'smon timer' )
     LOOP
        utl_file.put_line(fp1, DDATE||'{'||r.sid|| '{' || r.seq#|| '{' || r.event# || '{' ||
                          r.event || '{' || r.wt ||'{'||r.siw||'{'||r.p1||'{'||r.p1r||'{'||r.p1text||'{'
                          ||r.p2||'{'||r.p2r||'{'||r.p2text||'{'||r.p3 ||'{'||r.p3text ||'{'||r.shv||'{'
                          ||r.phv||'{'||r.rwo);
        utl_file.fflush(fp1);
     END LOOP ;
     dbms_lock.sleep($INTERVAL_WAIT);

     /* -----------------------------------------------------------------------------------------*/
     /* is it time to check and dump sql text ? we check this every $INTERVAL_SQL */
     /* -----------------------------------------------------------------------------------------*/
     if (delta_curr_interval > delta_max_interval ) then
        delta_curr_interval:=0 ;
        /* ........... check and dump new sql ........... */
        for r in ( select sql_id from v\\\$sqltext minus select sql_id from tbl_hv )
        LOOP
           insert into tbl_hv values (r.sql_id);
           for p in ( select sql_id hv, to_char(piece) pi, sql_text st from v\\\$sqltext
                             where sql_id=r.sql_id order by piece)
            LOOP
               utl_file.put_line(fp3,p.hv||'{'||p.pi||'{'||p.st);
            END LOOP;
        END LOOP;
        commit ;
        utl_file.fflush(fp1);
        utl_file.fflush(fp3);
        /* ........... check the semaphore    ........... */
        if ( f_sem_size > 0 ) then
           utl_file.fseek(fp2,0,NULL);
           utl_file.get_line(fp2,buffer,81);
           exit when buffer != 'run' ;
        end if;
        /* -----------------------------------------------------------------------------------------*/
        /* If delta of SQL is required we dump it here, also for v$systat and v$session_event
        /* -----------------------------------------------------------------------------------------*/
        /* ... Interval elapsed:  we dump v$sql and v$sysstat and reset the interval ..... */
        select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
        for d in (select SQL_ID hv, to_char(ROWS_PROCESSED) rp,to_char(DISK_READS) dr,
                      to_char(FETCHES) fe, to_char(EXECUTIONS) ex, to_char(loads) lo,
                      to_char(PARSE_CALLS) pa, to_char(BUFFER_GETS) bg, to_char(SORTS) so,
                      to_char(CPU_TIME) ct, FIRST_LOAD_TIME fl, to_char(PLAN_HASH_VALUE) phv,
                      to_char(child_number) chn, module md from v\\\$sql )
        LOOP
             utl_file.put_line(fp4, DDATE|| '{' || d.hv|| '{' || d.rp || '{' || d.dr|| '{'||d.fe || '{' || 
                               d.ex ||'{' || d.lo || '{' || d.pa || '{' || d.bg || '{' || d.so || '{' 
                               || d.ct || '{' || d.fl || '{' || d.phv || '{' || d.chn || '{' || d.md );
        END LOOP ;

        utl_file.fflush(fp4);
        select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
        for d in (select to_char(STATISTIC#) stn, name,to_char(value) value from v\\\$sysstat )
        LOOP
            utl_file.put_line(fp5,DDATE||'{'||d.stn||'{'||d.name||'{'||d.value );
        END LOOP;
        utl_file.fflush(fp5);

        /* ... we dump here v$session_stat to moke a profiler */ 
        select to_char(sysdate,'YYYYMMDDHH24MISS') into DDATE from dual ; 
        for d in (select to_char(a.sid) sid,to_char(b.serial#) serial,a.EVENT, to_char(a.TOTAL_WAITS) TOTAL_WAITS,
                   to_char(a.TOTAL_TIMEOUTS) TOTAL_TIMEOUTS, to_char(a.TIME_WAITED) TIME_WAITED, 
                   to_char(a.AVERAGE_WAIT) AVERAGE_WAIT, to_char(a.MAX_WAIT) MAX_WAIT,
                   to_char(a.TIME_WAITED_MICRO) TIME_WAITED_MICRO,b.program,b.module,b.action,b.username
               from v\\\$session_event a, v\\\$session b where a.sid=b.sid)
        LOOP
        utl_file.put_line(fp6,DDATE||'{'||d.sid || '{'|| d.serial  || '{'|| d.event  || '{'|| d.total_waits ||'{'|| 
                              d.total_timeouts ||'{'||d.time_waited ||'{'|| d.average_wait ||'{'|| d.max_wait||'{'|| 
                              d.time_waited_micro||'{'|| d.program||'{'||d.module||'{'|| d.action ||'{'||d.username);
        END LOOP;
        utl_file.fflush(fp6);

     end if;
     delta_curr_interval:=delta_curr_interval+$INTERVAL_WAIT;
     /* -----------------------------------------------------------------------------------------*/
     /* if we defined a max length for the sampling, otherwise it loops until manually cancelled */
     /* -----------------------------------------------------------------------------------------*/
     if ( $DURATION_SEC > 0 )then
          curr_len:=curr_len+$INTERVAL_WAIT ;
          if ( curr_len > max_len )then
              for r in ( select sql_id from v\\\$sqltext minus select sql_id sql_id from tbl_hv )
              LOOP
                 insert into tbl_hv values (r.sql_id);
                 for p in ( select sql_id hv, to_char(piece) pi, sql_text st from v\\\$sqltext
                             where sql_id=r.sql_id order by piece)
                 LOOP
                     utl_file.put_line(fp3,p.hv||'{'||p.pi||'{'||p.st);
                 END LOOP;
              END LOOP;
              commit ;
              utl_file.fclose(fp1);
              utl_file.fclose(fp3);
              if (delta = 1) then
                 utl_file.fclose(fp4);
                 utl_file.fclose(fp5);
              end if;
              exit ;
          end if;    
     end if ;
 END LOOP ;
 if ( f_sem_size > 0 ) then
      utl_file.fclose(fp2);
 end if ;
 utl_file.fclose(fp1);
 utl_file.fclose(fp3);
 if (delta = 1) then
    utl_file.fclose(fp4);
    utl_file.fclose(fp5);
 end if;
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
   #nohup $SCRIPT & 
   exec nohup $SCRIPT & 
   echo "Sampler started for waits and sql text : code for spl is : ${ORACLE_SID}_$FDATE"
else
echo "You can now type : 

          cd $SAMPLER_DIR
          nohup $SCRIPT &" 
fi
