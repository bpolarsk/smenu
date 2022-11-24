-- a nice procedure  to run stats pack on RAC : 
-- but also a demonstration on how to manage concurrent exclusive processes
create or replace procedure rac_statspack (i_snap_level in number) as
        m_status        number(38);
        m_handle        varchar2(60);
begin
 
        sys.dbms_lock.allocate_unique(
                lockname        => 'Synchronize Statspack',
                lockhandle      => m_handle
        );
 
        m_status := sys.dbms_lock.request(
                lockhandle              => m_handle,
                lockmode                => dbms_lock.x_mode,
                timeout                 => 600,         -- default is dbms_lock.maxwait
                release_on_commit       => false        -- which is the default
        );
 
        if (m_status = 0 ) then
                dbms_output.put_line(
                        to_char(sysdate,'dd hh24:mi:ss') ||
                        ': Acquired lock, running statspack'
                );
 
                statspack.snap(i_snap_level);
 
                dbms_output.put_line(
                        to_char(sysdate,'dd hh24:mi:ss') ||
                        ': Snapshot completed'
                );
 
                m_status := sys.dbms_lock.release(
                        lockhandle      => m_handle
                );
        else
                dbms_output.put_line(
                        to_char(sysdate,'dd hh24:mi:ss') ||
                        case m_status
                                when 1 then ': Lock wait timed out'
                                when 2 then ': deadlock detected'
                                when 3 then ': parameter error'
                                when 4 then ': already holding lock'
                                when 5 then ': illegal lock handle'
                                       else ': unknown error'
                        end
                );
        end if;
 
end;
/

-- dbms_job:

declare
    m_job   number;
    m_inst  number;
    m_date  date;
    m_jqs   number;
 
begin
    select  instance_number
    into    m_inst
    from    v$instance;
 
    dbms_job.submit(
        job     => m_job,
        what        => 'rac_statspack(7);',
        next_date   => trunc(sysdate + 1 / 24,'HH'),
        interval    => 'trunc(SYSDATE + 1 / 24,''HH'')',
        no_parse    => TRUE,
        instance    => m_inst,
        force       => true
    );
    commit;
 
    select
        next_date
    into    m_date
    from    dba_jobs
    where   job = m_job
    ;
 
    select
        value
    into    m_jqs
    from    v$parameter
    where   name = 'job_queue_processes'
    ;
 
    dbms_output.put_line('Job number: ' || m_job);
    dbms_output.put_line('Next run time: ' || to_char(m_date,'dd-Mon-yyyy hh24:mi:ss'));
    dbms_output.put_line('Current Job Queues: ' || m_jqs || ' (must be greater than zero)');
 
end;
/
