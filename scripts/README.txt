How to install smenu :

       A) contents of this installation manual :

       This installation manual contains 645.322,2 pages and ... 
       Hum .... no

       Just do :

       -Connect as user Oracle (Or the owner of the DB)
       -Uncompress the smenu_tar.tgz file, 
       -launch 'install.sh' or './install.sh' and look the television

       That's it!


How to add Shortcuts to Your environment :
==========================================
The shortcuts are used on the dot prompt. This is an alternate way of using Smenu.
To add the shortcuts in your environment, exit Smenu, go to your SBIN directory,
and just type ". ad" ( or . ./ad).  Shortcuts works only in ksh.

The SBIN directory is the root directory where you installed Smenu.


Why using Shortcuts  :
======================

Shortcuts add to your normal prompt a lot of commands. It gives 
immediate answer to your questions. Instead of journeying in all
menu's to launch a series of actions, you have the hability to 
launch these actions in sequence from the prompt. We have created
4 shortcuts that list them :
 
          - spx  : Unix shortcuts
          - sp   : All shortcuts for Oracle
          - spu  : Sub of sp ==> gather User related actions
          - spb  : Sub of sp ==> gather DB related actions

After having added the shortcuts, type one each of the 4 commands 
to see available commands.


Password :
==========
If you don't want to type in user and password each type, enter 
smenu (type sm) and go to module 1 option 5 to add user and passwords. 
Passwords are crypted. Some shortcuts works only with the user 'SYS',
but usely they works using the default user


Default user :
==============

The Default user is defined in SM/1.1. This is the user that is called 
by smenu to connect, unless instructed  by Smenu to user 'SYS'.

Add shortcuts :
===============

It is possible to add your own shortcuts : type 'vp' to edit addpar.sh 
(in SBIN/scripts),  add the shortcuts in one of the 4 sections. any short
Any shorcuts before 'sec3' is not visible by any 'sp' (show parameter) 
commands. However it will be part of your environment. if you add a
shortcuts after 'sect3' then run 'rgs' to regen the sp views.

be aware that your own shortcuts will be lost when you update release, 
so we advise you to keep a separate copy of addpar.sh and reinitialize
after refresh.


Tricks :
========

If you don't want to put 'addpar.sh' (ad) in your environment, you may do the following to add quickly smenu just for you :

A) Add in you oracle (or what else is the owner of the DB) an alias called smd :
   alias smd='cd /$SBIN' 
   Where sbin is the Smenu root directory, so that you can directly attack 
   with the next command : . ad.

B) make a symlink, to addpar.sh or to ad and type ". {mysymlink}



