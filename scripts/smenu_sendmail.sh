#!/bin/sh
# set -xv
# Author    : Bernard Polarski - 05-07-1999
#
# Known bug : The option -s retrieves only the first word. I tried to
#             quote or double quote the subject, no way. The chosen
#             work around implies to put -s before each word of the
#             subject.

TMPFILE=${TMPDIR:-/tmp}/mimemailer.$$
BOUNDARY="mimemail--boundary.$$"
disposition="attachment"  		# change to "inline" if your mail client prefers
MAIL_PRG="/usr/lib/sendmail -t" 
SUBJECT=""
#***********************************************
#***********************************************
if [ $# -le 1 ]; then
   cat <<-EOF
  
        Usage : smenu_sendmail.sh -b BODY_FILE -a ATTACH[n] -u USERS -s SUBJECT

        Argument :
                -b  : body of the mail
                -a  : Attach  file to join to this mail
                -u  : list of users to send to.
                -s  : Subject of the mail

        Only the list of users to send to is mandatory.

	EOF
  exit
fi


while getopts s:a:b:u: ARG
do
  case $ARG in
    a)  if [ "x-$ATTACH_FILE_LIST" = "x-" ];then
           ATTACH_FILE_LIST=$OPTARG
        else
           ATTACH_FILE_LIST=$ATTACH_FILE_LIST" "$OPTARG
        fi;;
    b)  BODY_FILE=$OPTARG;;
    s)  if [ "x-$SUBJECT" = "x-" ];then
           SUBJECT=$OPTARG
        else
           SUBJECT=$SUBJECT" "$OPTARG
        fi;;

    u)  if [ "x-$USER_LIST" = "x-" ];then
           USER_LIST=$OPTARG
        else
           USER_LIST=$USER_LIST","$OPTARG
        fi;;

    *)    echo "Unknown parameters -$ARG"
          exit 2;;
  esac
done
 
#----- check input ------------
if [ "x-$USER_LIST" = "x-" ];then
    echo "No target user ==> aborting"
    exit 0
fi


#**********************************************
# Create now the 'to' address of the email
#**********************************************
TO_ADDR=$USER_LIST
#**********************************************
# create the header and first boundary
#**********************************************
cat <<EOF > $TMPFILE
To: $TO_ADDR
Subject: ${SUBJECT}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="$BOUNDARY"

This is a multi-part message in MIME format.

--$BOUNDARY
Content-Type: text/plain; charset=US-ASCII;


EOF

#**********************************************
# read body file for the Body of the mail
#**********************************************
if [ ! "x-$BODY_FILE" = "x-" ];then
   cat $BODY_FILE >> $TMPFILE
fi

#**********************************************
# Add attach file if exists
#**********************************************
if [ ! "x-$ATTACH_FILE_LIST" = "x-" ];then
   for file in $ATTACH_FILE_LIST
       do
        filename=`basename $file`
        # create the second boundary for the enclosed file
cat <<EOF >> $TMPFILE

--$BOUNDARY
Content-Type: application/octet-stream; name="$filename"
Content-Transfer-Encoding: x-uuencode
Content-Disposition: $disposition; filename="$filename"

EOF
        # encode the potentially binary file

        uuencode $file  <$file >> $TMPFILE

   done
fi

#---------- send the email 
$MAIL_PRG < $TMPFILE
cp $TMPFILE /tmp/bb
rm -f $TMPFILE
