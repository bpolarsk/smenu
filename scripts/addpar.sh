# For all Stackanovitch of the Keystroke, here is your relief:
# Add some variables to the current shell : BPA 15/06/99
set -o vi


NAWK=/bin/awk
export NAWK
# --------- Variables==> ex : "cp file " ------
SBIN=/home/$USER/smenu  
SBINS=$SBIN/scripts
. $SBIN/smenu.env

if [ -f ${SBIN}/ad_wl ];then
   . $SBIN/ad_wl
fi

export SBINS
export SBIN

alias wpe='$SBINS/smenu_vis.ksh'                                #0# put you in edit mode in wpar data file

tp=$SBIN/tmp
m1=$SBIN/module1
m2=$SBIN/module2
m3=$SBIN/module3
m4=$SBIN/module4

OSBIN=$SBIN/../smenu_v7  
o1=$OSBIN/module1
o2=$OSBIN/module2
o3=$OSBIN/module3
o4=$OSBIN/module4
alias o0='cd $OSBIN'
alias o1='cd $OSBIN/module1'
alias o2='cd $OSBIN/module2'
alias o3='cd $OSBIN/module3'
alias o4='cd $OSBIN/module4'
alias mp='cd $SBIN/../smenu_perl'
alias mps='cd $SBIN/smenu_perl/SMENU'
alias vps='vi $SBIN/smenu_perl/SMENU/parse.pm'
alias slf='$SBIN/module2/s2/smenu_long_ops.ksh -f'
#alias ss="sqlplus '/ as sysdba'"
export  ss SBINS a1 a2 a3 a4
mod=$SBIN/../smenu_mod
# ---------------- Development command ---------------------
#alias must be maximum 4 letters
alias nsql='$SBIN/scripts/nsql'
alias ad='. $SBIN/scripts/addpar.sh'
alias ffind='$SBINS/ffind'
#sec2 --------------- Unix command not referenced in sp ---------------------
alias mkr='$SBINS/mk_release.sh'                                 # make a new relase 
alias sel='$SBINS/SELECT '                                       #0# Select prg using awk
alias smd='cd $SBIN'                                             # go to SBIN
alias lsm='ls -lt smenu_menu*'                                   # ls -l |more
alias lsh='ls -lt *.sh'                                          # list only .sh
alias lsq='ls -lt *.sql'                                         # list only .sql
alias lst='ls -lt *.txt'                                         # list only .txt
alias ms='cd $SBIN/scripts'                                      # go to SBINS
alias md='cd $SBIN/data'                                         # go tp SBIN/data
alias mt='cd $SBIN/standalone'                                    # go to SBIN/standalone
alias m1='cd $SBIN/module1'                                      # go to module1
alias m2='cd $SBIN/module2'                                      # go to module2
alias m3='cd $SBIN/module3'                                      # go to module3
alias m4='cd $SBIN/module4'                                      # go to module4
alias v1='vi $SBIN/module_1.sh'                                  # edit module1
alias v2='vi $SBIN/module_2.sh'                                  # edit module2
alias v3='vi $SBIN/module_3.sh'                                  # edit module3
alias v4='vi $SBIN/module_4.sh'                                  # edit module4
alias gl='vi ` vsp1 background_dump_dest`/alert_$ORACLE_SID.log' # Edit alert log
alias glt='tail -f ` vsp1 background_dump_dest`/alert_$ORACLE_SID.log' # Edit alert log
alias vm='vi `ls -t smenu_menu_* |  head -1`'                    # Edit last menu
alias xm='`ls -t smenu_menu_* |  head -1`'                       # Edit last menu
alias vlog='vi `ls -t *.log |  head -1`'                         # Edit last log
alias vpl='vi `ls -t *.pl |  head -1`'                           # Edit last modified perl
alias cnt='$SBIN/scripts/smenu_connect_sql.sh'                   # Pick S_USER; Connect DB
#alias cntu='$SBIN/scripts/smenu_connect_sql_u.sh'                # Coonect Using S_USER
#sec3 ---------------- Unix command referenced in spx ----------------------------------------
alias tp='cd $SBIN/tmp'                                          # go to SBIN/tmp
alias cl='clear'                                                 # clear screen
alias ll='ls -l '                                                # Long list files
alias lm='ls -l | more'                                          # Long list files with more
alias lt='ls -lt | more'                                         # List last files
alias psf='ps -ef | grep '                                       # ps -ef with grep on argument
alias psm='ps -ef | more'                                        # ps -ef with more
alias vt='vi `ls -t |  head -1`'                                 # Edit last file accessed in Dir
alias ct='cat `ls -t |  head -1`'                                # Cat last file accessed in Dir
alias vq='vi `ls -t *.sql | head -1`'                            # Edit last .sql
alias cq='cat `ls -t *.sql | head -1`'                            # Edit last .sql
alias vh='vi `ls -t *.sh | head -1`'                             # Edit last .sh
alias vk='vi `ls -t *.ksh | head -1`'                            # Edit last .ksh
alias vxt='vi `ls -t *.txt | head -1`'                           # Edit last .txt
alias xt='`ls -t *sh | head -1`'                                 # Run last *sh
alias tf='tail -f `ls -t |  head -1`'                            # tail -f last file in Dir
alias spm='more $SBINS/addpar.sh'    		                 # More of addpar.sh
alias vp='vi $SBINS/addpar.sh' 		    	                 ##0# edit addpar.sh
alias psi='ps -ef | grep $ORACLE_SID'                            # This Oracle instance processes
alias oh='cd $ORACLE_HOME'                                       # cd $ORACLE_HOME
alias on='cd $ORACLE_HOME/network/admin'                         # cd $ORACLE_HOME/network/admin
alias ol='cd $ORACLE_HOME/network/log'                           # cd $ORACLE_HOME/network/log
alias dbs='cd $ORACLE_HOME/dbs'                                  # cd $ORACLE_HOME/dbs
alias oa='. $SBINS/smenu_change_SID.sh'                       # Quick oraenv
alias ou='. $SBINS/smenu_change_S_USER.sh'                       # Quick oraenv
alias vhis='vi $SBINS/history.txt'                               # Edit history.txt
alias tn='vi $TNS_ADMIN/tnsnames.ora'
#sec4----------------- Smenu shortcuts : DB related (spb)----------------------------------
alias vdef='vi ${SBIN}/data/smenu_default_user.txt; chmod 600 ${SBIN}/data/smenu_default_user.txt' #0# view default user
alias vpas='vi $SBINS/.passwd; chmod 600 $SBINS/.passwd'         #0# view password file
alias ti='vi $ORACLE_HOME/dbs/init$ORACLE_SID.ora'               #0# Edit init.ora
#alias all='$SBINS/smenu_allocated.sh'                            # show filesystem distributions
alias sp='$SBINS/smenu_list_shortct_cat.ksh'    		 #0# Show Smenu Shortcuts
alias wp='$SBINS/wpar.sh'        		                 #0# what is it utility 
alias vsh='$SBINS/smenu_edit_alias.sh'                           #0# List or edit alias
alias vsl='vsh -l'                                               # List shortcut per category
alias dsk='$SBIN/scripts/smenu_dsk.sh'                           #4# describe a table,view
alias desc='$SBIN/scripts/smenu_dsk.sh'                          #describe a table,view
alias sm='cd $SBIN;$SBIN/smenu.sh'                               #0# Call smenu
alias up='$SBIN/module2/s1/smenu_uptime.sh'                      #1# DB uptime 
alias src='$SBIN/module2/s1/smenu_src.ksh'                       #4# Source view/funct/pkg/proc
alias dep='$SBIN/module2/s1/smenu_obj_deps.ksh'                  #4# List object tree dependency
alias cpl='$SBIN/module2/s1/smenu_obj_inv.ksh'                   #4# Compile
alias rac='$SBIN/module2/s1/smenu_rac.ksh'                       #1# Rac related info
alias sts='$SBIN/module2/s1/smenu_view_archive_mode.sh'          #1# show database status
alias mgm='$SBIN/module2/s1/smenu_mgm.sh'                        #3# grid/dbconsole views
alias vsp='$SBIN/module2/s1/smenu_list_init_param.sh'            #1# View all oracle sys parameter
alias dblk='$SBIN/module2/s1/smenu_list_of_db_links.sh'          #1# show DB links
alias cpt='$SBIN/module2/s1/smenu_cpt_obj.sh'                    #5# Users objects distribution
alias mts='$SBIN/module2/s2/smenu_mts.ksh'                       #5# all about MTS
alias sq='$SBIN/module2/s2/smenu_get_sql_figures.sh'             #6# Figures for SQL 
alias sqn='$SBIN/module2/s2/smenu_get_sqltext_60char.ksh'        #6# Show first 60 char
alias slo='$SBIN/module2/s2/smenu_long_ops.ksh'                  #6# Show first 60 char
alias soc='$SBIN/module2/s2/smenu_handle.ksh'                    #a# view cursors and handles
alias ks='$SBIN/module2/s2/smenu_kill_session.sh'                #5# Kill user session
alias ksd='$SBIN/module2/s2/smenu_disconnect_session.sh'         #5# Disconnect immediate session
alias sa='$SBIN/module2/s2/smenu_session_activity.sh'            #5# check user activity
alias st='$SBIN/module2/s2/smenu_get_sql_text.ksh'               #6# Get the sql text for an address
alias sl='$SBIN/module2/s2/smenu_sessions_overview.sh'           #5# Show open sessions info
alias aud='$SBIN/module2/s3/smenu_list_audit_on.ksh'             #0# List audit actions
alias drm='$SBIN/module2/s3/smenu_drm.ksh'          #b# Resource group manager
alias rol='$SBIN/module2/s3/smenu_db_role.sh'                    #b# all about roles
alias usr='$SBIN/module2/s3/smenu_user.ksh'                      #b# all about User
alias prf='$SBIN/module2/s3/smenu_list_profile_attribute.ksh'    #b# List profile attributes
alias idx='$SBIN/module2/s4/smenu_desc_idx.ksh'                  #4# Show all about indexes
alias tbl='$SBIN/module2/s4/smenu_desc_table.ksh'                #4# Everything about table
alias obj='$SBIN/module2/s4/smenu_show_obj.ksh'                  #4# obj with file_id & block_id
alias seg='$SBIN/module2/s4/smenu_seg.ksh'                       #4# all about segment statistics
alias frg='$SBIN/module2/s5/smenu_free_space_summary.ksh'        #3# Tbs free Frag {par :[][b][g]}
alias lstd='$SBIN/module2/s5/smenu_disk_lst.ksh'                 #3# List datafiles
alias asm='$SBIN/module2/s5/smenu_asm.ksh'                       #3# List asm disk stats
alias mod='$SBIN/module2/s5/smenu_show_tab_mod.ksh'              #4# Table and index monitor
alias buf='$SBIN/module2/s6/smenu_db_buffer.ksh'                 #a# all about buffer
alias sys='$SBIN/module2/s6/smenu_sys_stats.ksh'                 #9# Show system statistics
alias ses='$SBIN/module2/s6/smenu_session_stats.ksh'             #9# Show system statistics
alias sls='$SBIN/module2/s6/smenu_system_event.sh'               #9# Show system events
alias sle='$SBIN/module2/s6/smenu_session_event.sh'              #9# Show sessions events
alias wss='$SBIN/module2/s6/smenu_session_wait.sh'               #9# Show sessions wait 
alias srv='$SBIN/module2/s6/smenu_service.ksh'                   #9# Show all about services
alias lck='$SBIN/module2/s7/smenu_all_locks.ksh'                 #7# all about locks
alias lat='$SBIN/module2/s7/smenu_all_latch.sh'                  #7# All about latches
alias spx='$SBIN/module2/s7/smenu_show_pq_slave.ksh'             #6# Show parallel query slave
alias lc='$SBIN/module2/s7/smenu_lc.ksh'                         #a#  library cache pin info
alias par='$SBIN/module2/s8/smenu_show_parse_values.sh'          #a# Show parsing perf
alias pard='$SBIN/module2/s8/smenu_show_parse_recurse.sh'        #a# Show recursive parsing
alias sga='$SBIN/module2/s8/smenu_share_mem_usage.sh'            #a# Shared mem usage
alias lom='$SBIN/module2/s8/smenu_large_object_in_mem.sh'        #a# Large obj in memory
alias lsqr='$SBIN/module2/s8/smenu_get_str_in_sqlarea.ksh'       #5# retrieve SQL with substring
alias tx='$SBIN/module2/s8/smenu_show_transaction.ksh'           #6# Show transactions
alias rlbs='$SBIN/module2/s9/smenu_rollback_size.sh'             #6# show roll. size and occupancy
alias rdl='$SBIN/module2/s9/smenu_show_redo_logs.ksh'            #8# list redo info
alias lsbk='$SBIN/module2/s9/smenu_rman_show_bk.ksh'             #0# rman show backup piece
alias owi='$SBIN/module3/s1/smenu_owi.ksh'                       #9# part of 'spl'
alias spl='$SBIN/module3/s1/smenu_menu_monitor.ksh'              #9# owi selection screen
alias apl='$SBIN/module3/s2/smenu_show_applied_arc.ksh'          #8# show applied rpl
alias dg='$SBIN/module3/s2/smenu_show_logical_dg.ksh'            #8# Logical dataguard main command
alias ttbl='$SBIN/module3/s2/smenu_transportable_tbs.ksh'        #3# Check/exp/emp transportable tbs
alias parg='$SBIN/module3/s2/smenu_list_std_param.ksh -g'        #8# show standby init parm
alias part='$SBIN/module3/s2/smenu_list_std_param.ksh -t'        # show tunning init param
alias pars='$SBIN/module3/s2/smenu_list_std_param.ksh -s'        #8# show streams init parm
alias lsrv='$SBIN/standalone/sworldine_db_server.sh'             #0# list db per servers
#sec5----------------- Smenu shortcuts : user and session related  ------------------------
# M3
alias jb='$SBIN/module3/s3/smenu_jobs.ksh'                       #1# All about jobs
alias shed='$SBIN/module3/s3/smenu_scheduler.ksh'                #1# List scheduler jobs
#alias smtp='$SBIN/module3/s5/smenu_show_missing_tab_parts.ksh'   3 Show missing tab parts
#alias smtga='$SBIN/module3/s5/smenu_sub_gen_scr_exch_all_subpart.ksh'  3  gen all sub exch
alias sstv='$SBIN/module3/s4/smenu_choose_session_to_set_event.ksh' #2# Set trace in session
#alias sstp='$SBIN/module3/s4/smenu_statpack.ksh'                 2 Run statpack
alias sx='$SBIN/module3/s4/smenu_dyn_explain_plan.ksh'           #2# Display dynamic explain plan
alias aw='$SBIN/module3/s4/smenu_awr.ksh'                        #2# All about awr
alias xpl='$SBIN/module3/s4/smenu_explain_plan.sh'               #2# Explain plan 
alias sta='$SBIN/module3/s6/smenu_gather_stat_tbl.ksh'           #4# gather stats on table
alias app='$SBIN/module3/s8/smenu_stream_apply.ksh'              #8# stream apply
alias cap='$SBIN/module3/s8/smenu_stream_capture.ksh'            #8# stream capture
alias rul='$SBIN/module3/s8/smenu_stream_rules.ksh'              #8# stream rules
alias aq='$SBIN/module3/s8/smenu_stream_aq.ksh'                  #8# all about advance queues
alias dbrep='$SBIN/module3/s9/smenu_run_dbms_repair.ksh'         #0# repair corrupt blocks
alias gc='$SBIN/module3/s9/smenu_emgc.ksh'                        #2# Grid control
alias prop='$SBIN/module3/s8/smenu_stream_propagation.ksh'       #8# stream propagation
alias lgm='$SBIN/module3/s8/smenu_logminer.ksh'                  #2# Logminer interface
alias mw='$SBIN/module3/s8/smenu_materialized_view.ksh'          #8# all about materialized views
alias rep='$SBIN/module3/s8/smenu_advance_replication.ksh'       #8# Advance replication with MW
alias tkp='$SBINS/smenu_choose_tkprof.sh'                        #2# Create explain plan from .trc
#alias mlio='$SBINS/run_system_sql.sh 3/s5 max_sql_disk_logical_read' # sql that does maximum io
#alias fio='$SBINS/run_system_sql.sh 3/s5 file_report'            # Report file io 
#alias tio='$SBIN/module2/s5/smenu_get_diff_io.sh'                # File io during x seconds
#alias mts='$SBIN/module2/s12/smenu_menu_mts.sh'                  # Multithreads server
#alias rl='$SBIN/module2/s1/smenu_resource_limit.sh'              # show resource limit
alias adm='cd $(dirname `vsp -p user_dump_dest`)'                   #0# cd to admin dir
alias admu='cd $(dirname `vsp -p  user_dump_dest`)/udump'            #0# cd to admin dir
alias met='$SBIN/module2/s6/smenu_metric.ksh'                     #9# all about metrics
alias dpf='$SBIN/module2/s2/smenu_dbms_profiler.ksh' #5# all about dbms_profiler
