Restricted User Linux
=================

Scripts to restrict Linux users for SSH, FTP, SFTP

## restrictuser.sh

~~~
restrictuser.sh <username> 
~~~

This script enforces jailed ssh sessions for the specified  *user* whenever 
they login to the server thereafter. The *user* is restricted to
the list of commands specified in **$APPS**.

- It will work on most Linux distributions. I have tested on Ubuntu and Centos.


- The users jailed home is under */jail/home/user*
    - A backup is made of *user*'s old /home directory to */home/user.orig*

- All the libraries needed by the specified $APPS are copied to the chrooted
environment automatically.

### Must Know

- Configurations are made to */etc/ssh/sshd_config* by the script to set 
*ChrootDirectory*.  The ssh service is supposed to be restarted manually for
the change to take effect.

- Here are the changes that are made to *sshd_config*
```
Match group jailed
  ChrootDirectory /home/utkarsh
  AllowTCPForwarding no
  X11Forwarding no
```
- additional recommended change
```
PermitRootLogin no
AllowGroups wheel jailed
```
