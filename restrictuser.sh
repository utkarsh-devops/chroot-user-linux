#!/bin/bash
#---------------------------------------------------------------------------
#description :restricts existing user with limited commands when they ssh to server.
#author      :Utkarsh Sharma
#blog        :https://utkarshblog.weebly.com/
# ----------------------------------------------------------------------
# Usage:  jailuser.sh <username> 
#
# This script creates a jailed ssh session for user <username> whenever they
# they login to the server thereafter. The <username> is restricted to
# the list of commands specified in $APPS.

# The users jailed home is under /jail/home/<username>
# A backup is made of <username> old /home directory to /home/<username>.orig
#
# Changes are made to /etc/ssh/sshd_config by the script to set the
# ChrootDirectory.  The ssh server will need to be restarted.
# ----------------------------------------------------------------------
USERNAME=$1

JAILPATH='/utkarsh'
mkdir -p $JAILPATH

#
# Add the apps you want the user to have access to in their jailed environment.
#
APPS="/bin/bash /bin/cat /bin/cp /bin/grep /bin/ls /bin/mkdir /bin/more /bin/mv /bin/pwd /bin/rm /bin/rmdir /usr/bin/du /usr/bin/head /usr/bin/id /usr/bin/less /usr/bin/ssh /usr/bin/scp /usr/bin/tail /usr/bin/rsync"


if ! getent group jailed > /dev/null 2>&1
then
  echo "creating jailed group"
  groupadd -r jailed
fi 

if ! grep -q "Match group jailed" /etc/ssh/sshd_config
then
  echo "* jailing anyone in jailed group"

  echo "
Match group jailed
  ChrootDirectory $JAILPATH
  AllowTCPForwarding no
  X11Forwarding no
" >> /etc/ssh/sshd_config

  echo
  echo "** please restart ssh daemon, then re-run script again"
  exit 0
fi


if [ -z "$USERNAME" ]
then
  echo "You must specify a username" >&2
  echo "USAGE $0 <username>" >&2
  exit 1
fi

if getent passwd $USERNAME > /dev/null 2>&1
then 
  echo "* User $USERNAME exists. Jailing them"
else
  echo "User $USERNAME does not exist. Add the user first then run this script again" >&2
  exit 3
fi

echo "* adding user to jailed group - so that ssh will jail them automatically when they login"

usermod -a -G jailed ${USERNAME}

group_name=`id -gn ${USERNAME}`

chrooted_home="$JAILPATH/home"
virtual_home="$chrooted_home/$USERNAME"
 

mkdir -p ${chrooted_home}
chown root:root ${chrooted_home}
chmod 755 ${chrooted_home}

mkdir -p ${virtual_home}
chown $USERNAME:$group_name ${virtual_home}
chmod 0700 ${virtual_home}

# If root ever su's to users home this makes sure we go to the correct
# home directory. 

# backup old directory.
if [ ! -h "/home/${USERNAME}" -a -d "/home/${USERNAME}" ]
then
  echo "* Backing up users previous home to /home/${USERNAME}.orig"
  mv /home/${USERNAME} /home/${USERNAME}.orig
fi

if [ ! -e "/home/${USERNAME}" ]
then
  echo "* Creating link from chrooted home to /home"
  ln -s ${virtual_home} /home/${USERNAME}
fi


cd $JAILPATH 
mkdir -p dev
mkdir -p bin
mkdir -p lib64
mkdir -p etc
mkdir -p usr/bin
mkdir -p usr/lib64
 
# First time
if [ ! -f etc/group ] ; then
 echo "* setting up the jail for the first time"
 grep -E "^(nobody|nogroup)" /etc/group > ${JAILPATH}/etc/group
fi

if [ ! -f etc/passwd ] ; then
 grep -E "^(nobody)" /etc/passwd > ${JAILPATH}/etc/passwd
fi

# Append the primary group if not there.
if ! grep -q "^${group_name}:" ${JAILPATH}/etc/group
then 
  grep "^${group_name}:" /etc/group >> ${JAILPATH}/etc/group
fi

# Append this user if not already there.
if ! grep -q "^${USERNAME}:" ${JAILPATH}/etc/passwd
then 
  grep "^${USERNAME}:" /etc/passwd >> ${JAILPATH}/etc/passwd
fi


#
# The libnss_files library is needed so usernames rather than uid's show up
# when users do directory listings.
#
if [ -e "/lib64/libnss_files.so.2" ]
then
 cp -p /lib64/libnss_files.so.2 ${JAILPATH}/lib64/libnss_files.so.2
fi

# Debian/Ubuntu derivatives
if [ -e "/lib/x86_64-linux-gnu/libnss_files.so.2" ]
then
  mkdir -p ${JAILPATH}/lib/x86_64-linux-gnu
  cp -p /lib/x86_64-linux-gnu/libnss_files.so.2 ${JAILPATH}/lib/x86_64-linux-gnu/libnss_files.so.2
fi


# Creating necessary devices
[ -r $JAILPATH/dev/urandom ] || mknod $JAILPATH/dev/urandom c 1 9
[ -r $JAILPATH/dev/null ]    || mknod -m 666 $JAILPATH/dev/null    c 1 3
[ -r $JAILPATH/dev/zero ]    || mknod -m 666 $JAILPATH/dev/zero    c 1 5
[ -r $JAILPATH/dev/tty ]     || mknod -m 666 $JAILPATH/dev/tty     c 5 0

 
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# We copy libraries everytime we add a new user to ensure that we always have the latest libraries after OS upgrades.
#
for prog in $APPS
do
  cp $prog ${JAILPATH}${prog} > /dev/null 2>&1
  if ldd $prog > /dev/null
  then
    LIBS=`ldd $prog | grep '/lib' | sed 's/\t/ /g' | sed 's/ /\n/g' | grep "/lib"`
    for l in $LIBS
    do
      mkdir -p ./`dirname $l` > /dev/null 2>&1
      cp $l ./$l  > /dev/null 2>&1
    done
  fi
done
 
echo "Chrooted environment created under ${JAILPATH} for ${USERNAME}"
echo
