
#!/bin/ksh
#
# smenu_find_home.sh
# Script to find the ORACLE_HOME value from oratab using the 
# ORACLE_SID supplied as a parameter
#
#################################################
# Set up variable
#################################################
ORATAB_DIR=/var/opt/oracle
ORATAB_FILE=${ORATAB_DIR}/oratab
#################################################
# Verify if oracle SID is passed as a parameter 
#################################################
if test $# -ne 1
then
   echo NOSIDNAME
   return 1
fi
PSID=$1
############################################################################
# Read oratab file to find ORACLE_HOME for the supplied instance name #
############################################################################
cat $ORATAB_FILE | while read LINE
do
  case $LINE in
    \#*)            ;;      #comment-line in oratab
      *)
                            #Proceed only if third field is 'Y'.
#   if [ "`echo $LINE | awk -F: '{print $3}' -`" = "Y" ]
#   then
      OSID=`echo $LINE | awk -F: '{print $1}' -`
      if [ "$OSID" = "$PSID" ]
      then
         OHOME=`echo $LINE | awk -F: '{print $2}' -`
         echo $OHOME
         return 0
      fi
#   fi
  esac
done
echo INVALIDSID
return 1
#################
# End of Script #
#################
