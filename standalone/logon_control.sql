Create or replace  trigger SYS.logon_control
-- *****************************************************************************
--   NAME:	 LOGON_CONTROL
--   PURPOSE:	 Filter login and set auditing options
--
--   REVISIONS:
--   Ver	Creation Date  Author		Description
--   ---------	----------  ---------------  ------------------------------------
--   1.1	15/05/2009  Bernard Polarski logon trigger to allow/deny entry
--
--   History : 2009_05_15 -  1.0    bpa First  release
--	       2009_09_02 -  1.1    bpa Added  test on osuser
--	       2009_09_24 -  1.2    bpa Fix bug on program name with blanks not allowed
AFTER LOGON ON DATABASE
DECLARE
  s_sid 	number;
  s_prg 	varchar2(48);
  s_srv 	varchar2(64);
  s_osu 	varchar2(30);
  s_mch 	varchar2(64);
  s_usr 	varchar2(30);
  v_msg 	varchar2(512) ;
  v_log_allow	varchar2(1):='N' ;
  v_fga 	varchar2(1):='Y' ;
  v_role	number;
  DEBUG 	varchar2(1) := 'N' ;
  procedure fout (msg in varchar2) is
  begin
    --dbms_output.put_line(msg);
    sys.dbms_system.ksdwrt(2,to_char(sysdate)|| ' -- ' || msg );
  end ;
  procedure not_allowed is
  begin
      dbms_output.put_line('not_allowed called');
  end ;
  function is_contained ( p_line in varchar2, p_arg in varchar2 )
  return number
  is
  v_first      varchar2(1);
  v_occ        number;			   -- number of occurence of % in p_arg
  var	       varchar2(256);		   -- P_arg with all % replaced with a pattern for regexp_replace
BEGIN
-- ==================
-- Package overview
-- ==================
--
-- This comment contains the description and code forall components needed by this
--
-- 1) This trigger filter the logon on the DB based on rules from table LOGON_CONTROL
-- In addtition, you may decide to set interactively or not a debug feature that logs all
-- logon decision into the alert.log. Thought it spam a bit the alert.log, this feature
-- is usefull to see the trigger in action, specially after you have added/modifed a rule.
--
-- 2) Second feature is the ability to set a Fine Grain Audit (FGA) flag.
-- First revision of the FGA policy was a call made by "DBMS_FGA.ADD_POLICY.AUDIT_CONDITION",
-- to a PL/SQL function which holds the business logic and returned a value 'Y' or 'N' to decide if the current
-- transaction must be logged. The loginc into the function compared the current owner to the main owner and if it matches
-- then returned 'N' (don't log) to avoid a huge number of rows into fga_log$. In all other case it returned 'Y'.
-- So if you logon with the main application schema, you were not audited.
--
-- This current way of managing the FGA by logon trigger, setting a variable at session level (called context) is superior.
--     a) The decision to log or not is calclated only once. The call to audit_condition points to a variable into
--	  PGA where the response is awaiting and not to a function  that must be run each time to get a response.
--	  (better performance).
--     b) it is now possible to audit a main schema transaction when the session is not one of an accredited application
--	  server. An accredited application server session is one of the main schema that uses a specific service, program,
--	  comes from a specific location. In this case the 'role' help to decide audit or not. But still role may be used
--	  to audit all people with the DBA role.
--	  (for instance create a line with %  in Service, username, client_machine, program and set ROLE='DBA')
--
-- Setting the decision to audit or not in the logon trigger enabled a more finer decision.
--
--
-- Note: User with the ADMINISTER DATABASE TRIGGER will bypass the exception raised when the logon trigger deny access.
--	thus, these user will always logon
--
--
-- # This table hold the rules. each line is a rule an must have a unique RULE?ID. the rules are evaluatd in asc order of RULE_ID.
-- # As soon as a mach is found for all columns of a rule, the logon trigger terminates immediatly and grant the connect.
--
-- CREATE TABLE SYS.LOGON_CONTROL
-- (
--   RULE_ID	     VARCHAR2(10 BYTE)		   NOT NULL,
--   SERVICE_NAME    VARCHAR2(64 BYTE),
--   CLIENT_MACHINE  VARCHAR2(64 BYTE),
--   USERNAME	     VARCHAR2(30 BYTE),
--   PROGRAM	     VARCHAR2(64 BYTE),
--   OSUSER	     VARCHAR2(64 BYTE),
--   ROLE	     VARCHAR2(64 BYTE),
--   IS_RULE_ACTIVE  VARCHAR2(1 BYTE)		   DEFAULT 'Y',
--   FGA_AUDIT	     VARCHAR2(1 BYTE)		   DEFAULT 'Y',
--   RULE_LABEL      VARCHAR2(32 BYTE),
--   RULE_DESCR      VARCHAR2(64 BYTE)
-- )
-- TABLESPACE SYSAUX;	   -- don't put the table in system tbs as block sumcheck is always perform on SYSTEM
-- ALTER TABLE SYS.LOGON_CONTROL ADD (
--   CHECK ("IS_RULE_ACTIVE"='Y' OR "IS_RULE_ACTIVE"='N'),
--   CHECK (FGA_AUDIT in ('Y','N')));
--
-- #................................................................................................
-- #  Package to hold the trusted function to set the value of syscontext variable 'audit_fga_var';
-- #................................................................................................
-- CREATE OR REPLACE package SYS.pci_fga_context_pkg is
-- procedure set_context_fga_on;
-- procedure set_context_fga_off;
-- end pci_fga_context_pkg;
-- /
-- CREATE OR REPLACE package body SYS.pci_fga_context_pkg is
-- procedure set_context_fga_on is
-- begin
--   dbms_session.set_context('pci_fga_context','audit_fga_var','Y');
-- end ;
-- procedure set_context_fga_off is
-- begin
--   dbms_session.set_context('pci_fga_context','audit_fga_var','N');
-- end ;
-- end pci_fga_context_pkg;
-- /
-- SQL>  create or replace context pci_fga_context using pci_fga_context_pkg;
--
-- #................................................................................................
-- # example of script to create FGA rules for a full schema
-- #................................................................................................
-- #!/usr/bin/ksh
-- # script : cr_all_fga_rule.ksh
--
-- FUSER=MY_NAME
-- FGA_NAME=FGA_POL_
-- sqlplus  / as sysdba <<EOF
-- declare
--  cpt number:=0;
--  polname varchar2(30);
-- begin
--  for c1 in ( select table_name from dba_tables where owner = '$FUSER' )
--  loop
--   polname:='$FGA_NAME'|| to_char(cpt) ;
--   cpt:=cpt + 1;
--   DBMS_FGA.ADD_POLICY(
--	 object_schema	 => '$FUSER',
--	 object_name	 => c1.table_name,
--	 policy_name	 => polname ,
--	 audit_column	 => NULL,
--	 audit_condition => 'nvl(sys_context(''pci_fga_context'',''audit_fga_var''),''N'') = ''Y''', -- background proc return null here
--	 statement_types => 'SELECT,INSERT,UPDATE,DELETE',
--	 audit_trail	 => DBMS_FGA.DB + DBMS_FGA.EXTENDED);
--   end loop;
-- end;
-- /
-- EOF
-- # end of script
--
--
-- #................................................................................................
-- #  Package to hold the trusted function to set the value of syscontext variable 'trace';
-- #................................................................................................
-- CREATE OR REPLACE package SYS.logon_ctx_pkg is
-- procedure set_ctx_trace_on ;
-- procedure set_ctx_trace_off ;
-- end logon_ctx_pkg;
-- /
-- CREATE OR REPLACE package body SYS.logon_ctx_pkg is
-- procedure set_ctx_trace_on is
-- begin
--    dbms_session.set_context('logon_control_ctx','trace', 'Y');
-- end ;
-- procedure set_ctx_trace_off is
-- begin
--    dbms_session.set_context('logon_control_ctx','trace', 'N');
-- end ;
-- end logon_ctx_pkg;
-- /
-- sql> create context logon_control_ctx using logon_ctx_pkg accessed globally ;
--
-- # set debug on	:
-- sql> exec logon_ctx_pkg.set_ctx_trace_on ;
-- # set  debug off:
-- sql> exec logon_ctx_pkg.set_ctx_trace_off ;
-- #................................................................................................
--
-- ================
-- TRIGGER LOGIC:
-- ================
--
--     Logic in this trigger is of the form:
--     Oracle User ( if empty use osuser )
--	List condition
--	[
--	  client machines
--	  service name
--	  role
--	  program
--	] --> met? ---> YES -- is logging allowed ? --> yes --> set FGA (Y/N) and exit
--		   ---> No  Next rule
--    No more rule --> Deny login
--
--
--    Note: Values for columns:  NULL	--> skip test (exception for username/osuser: one of the two must exist)
--			     <Value> --> must match regexp to be TRUE
--			      %      --> Always TRUE
--
--    string arg will be of the from :
--	    abcdefgh	: exact match			--> supported
--	    abcd%	: start match			--> supported
--	    %fgh	: end match			--> supported
--	    abc%gh	: middle match			--> supported
--	    %bcef%	: both extremity match		--> supported
--	    ab%e%f	: multiple match		--> supported
--	    %		: universal match		--> supported
-- *****************************************************************************
     if p_line = p_arg then
	if DEBUG = 'Y' then fout('exact match found'); end if ;
	return 1;			   -- exact match found
     elsif p_arg = '%' then		   -- universal matches
	if DEBUG = 'Y' then fout('universal match found'); end if ;
	return 1;
     else
	-- p_arg is maybe a substring of p_line. let's check occurence of wildcard in p_arg
	v_occ:=(LENGTH(p_arg)-(LENGTH(REPLACE(LOWER(p_arg),'%') )))/ LENGTH('%') ;
	if v_occ=0 then
	   return -1 ; -- no wildcard in name and exact match was already not true : no match possible
	else	       -- there is one or many wildcards
	   -- start  '%efg'
	   if v_occ = 1 and substr(p_arg,1,1) = '%'  then
	      var:=regexp_replace(p_arg,'%','^[[:alnum:][:punct:][:space:]][[:alnum:][:punct:][:space:]]*')||'$';  -- p_line=SYSTEM p_arg=%TEM var=^[A-Z0_9_-]*TEM$
	   -- end 'abc%'
	   elsif v_occ = 1 and instr(p_arg,'%' ) = length(p_arg) then
		var:=regexp_replace(p_arg,'%','[[:alnum:][:punct:][:space:]][[:alnum:][:punct:][:space:]]*');	 -- p_line=SYSTEM p_arg=SYS% var=SYS[A-Z0_9_-]*
	   -- Middle 'ab%fg' or  multplie wildcards 'ab%d%fg'
	   else
	       var:=regexp_replace(p_arg,'%','[[:alnum:][:punct:][:space:]][[:alnum:][:punct:][:space:]]*')||'$';  -- p_line=SYSTEM p_arg=SY%EM var=SY[A-Z0_9_-]*TEM$
	   end if;										 -- or p_arg=S%T%M var=S[A-Z0_9_-]*T[A-Z0_9_-]*M$
	 -- Perform now the test using 'var' as pattern to see if p_arg is contained into p_line
	   if  length(p_line)>	nvl(length( regexp_replace(p_line,var,'')),0)  then
		if DEBUG = 'Y' then fout('partial found'); end if ;
		return 1 ;
	   else
	       return -1;
	   end if;
	 end if ;
     end if;
  end;
BEGIN
     SELECT
	   sid, program, Service_Name, Machine, username, osuser
	   INTO s_sid, s_prg, s_srv, s_mch, s_usr, s_osu
     FROM
	  sys.v_$session
     WHERE
	  sid = sys_context('USERENV', 'SID');
     if upper(sys_context('LOGON_CONTROL_CTX','trace' )) = 'Y' then
	DEBUG:='Y';
     end if;
     if DEBUG = 'Y' THEN
	v_msg:='sid=' ||to_char(s_sid)	||' s_usr=' || s_usr|| ' s_osu=' || s_osu ||
	       ' s_mch='|| s_mch|| ' s_srv=' || s_srv ;
	fout(v_msg);
     END IF;
    -- These two values are default, they will not let you login or if you are allowed to login, you will be audited.
    -- You need to find a friend rules to affect them.
    if s_usr is null then
	v_fga:='N' ;
     else
	v_fga:='Y' ;
     end if;
     -- Get now the log control candidate rules
     -- Each row here is a rule and a candidate user will be allowed into db if he finds a rule that satisfy all s_<var>
     -- For each C row, if one S_<var> does not match then the rule examination is immediatly abandonned and next rule is loaded
     -- If candidate logon user did not alter the variable V_LOG before all rules are exhausted, then he is denied entry to db
     for c in ( select rule_id,username, osuser, client_machine, Service_Name, role, fga_audit, program
		       from sys.logon_control where is_rule_active = 'Y' order by rule_id)
     loop
	  if DEBUG = 'Y' THEN fout('Loading rule : '||c.rule_id) ; end if ;
	  -- If there is no rule for username, then candidate loging fails immediately unless osuser match a rule
	  if DEBUG = 'Y' THEN fout('Check username: '||s_usr || ' rule:' || c.username ) ; end if ;
	  if  c.username is null then
	      if c.osuser  is null then
		  goto to_end ;
	      elsif is_contained(s_osu, c.osuser) = -1 then
		  goto to_end ;
	      end if;
	  elsif is_contained(s_usr, c.username) = -1 then
		 goto to_end ;
	  end if;
	  -- If there is no rule for the client machine, then candidate login succeed this post
	  if DEBUG = 'Y' THEN fout('Check Host: '||s_mch || ' rule:' || c.client_machine  ) ; end if ;
	  if c.client_machine is not null and is_contained(
	     translate(upper(s_mch),'\','-'), translate(upper(c.client_machine),'\','-') ) = -1 then
	     goto to_end ;
	  end if ;
	 -- If there is no rule for the service_name, then candidate login succeed this post
	  if DEBUG = 'Y' THEN fout('Check Service: '||s_srv || ' rule:' || c.service_name  ) ; end if ;
	  if c.service_name is not null and is_contained(s_srv,c.service_name) = -1 then
	     goto to_end ;
	  end if ;
	 -- If there is no rule for the program then candidate login succeed this section
	  if c.program is not null then
	      if DEBUG = 'Y' THEN fout('Check Program: '||s_prg || ' rule:' || c.program ) ; end if ;
	      if is_contained(s_prg,c.program) = -1 then
		  goto to_end ;
	      end if;
	  end if ;
	 -- If there is no rule for osuser then candidate login succeed this section
	  if c.osuser is not null then
	      if DEBUG = 'Y' THEN fout('Check Osuser: '||s_osu || ' rule:' || c.osuser	) ; end if ;
	      if is_contained(s_osu,c.osuser) = -1 then
		  goto to_end ;
	      end if;
	  end if ;
	 -- check on Role
	  if c.role is not null and trim(c.role) <> '%' then
	     if DEBUG = 'Y' THEN fout('Check if ' || s_usr ||' has access to role: ' || upper(c.role ) ); end if ;
	     select count(*) into v_role
		   from (select grantee,
				SYS_CONNECT_BY_PATH(grantee, '/') connect_path,
				granted_role, admin_option
			   from sys.dba_role_privs
			   where decode((select type# from sys.user$ where name = upper(grantee)),
					 0, 'ROLE',
					 1, 'USER') = 'USER'
			   connect by granted_role = prior grantee
			   start with granted_role= upper(c.role) )
		 where grantee = s_usr ;
	      if  v_role = 0 then
		  fout('No access found');
		  goto to_end ;
	      end if;
	      if DEBUG = 'Y' then fout('access found:'||to_char(v_role)); end if;
	  end if;
	  v_log_allow:='Y';
	  v_fga:=c.fga_audit ;
	  exit;
	  -- end of loop
	 <<TO_END>> null;
     end loop;
     if v_log_allow = 'N' then
	if DEBUG = 'Y' then
	    fout( 'No acceptable rules found, login is NOT allowed') ;
	    fout('--------------------------------') ;
	else
	    fout('LOGON_CONTROL denied usr:' ||s_usr|| ' prg:'||s_prg || ' osusr:'||s_osu|| ' host:'||s_mch||' srv:'||s_srv);
	end if ;
	if s_usr = 'SYS' or s_usr = 'SYSTEM' then
	   null ;   -- users with DBA grants are immune to this raise but a tracefile will be generated. We avoid this trace
	else
	  RAISE_APPLICATION_ERROR( -20003,'No access rules found for your profile, Access is Denied !!!');
	end if;
     else
	if DEBUG = 'Y' then fout('Login allowed for ' || s_sid||':'||s_usr) ; end if;
	-- logon is allowed, we set the FGA flag on/off
	if v_fga = 'Y' then
	   if DEBUG = 'Y' then fout( 'FGA trace set on') ; end if ;
	   pci_fga_context_pkg.set_context_fga_on ;
	else
	   if DEBUG = 'Y' then fout( 'FGA trace set off') ; end if ;
	   pci_fga_context_pkg.set_context_fga_off ;
	end if;
	if DEBUG = 'Y' then fout('--------------------------------') ; end if;
     end if ;
    EXCEPTION
      when NO_DATA_FOUND then
	if DEBUG = 'Y' then fout('in no data found'); end if ;
END;
