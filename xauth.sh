#!/bin/bash
# Script to automate X11 package installation, ssh config and cookie script implementation

[[ $(cat /etc/*-release) =~ "Red" ]] && os="rh"
[[ $(cat /etc/*-release) =~ "Cent" ]] && os="rh"
[[ $(cat /etc/*-release) =~ "Ubuntu" ]] && os="deb"

case $os in
  "rh")
  yum -y install xauth
  yum groupinstall "X Window System" -y
  ;;
  "deb")
  apt-get update -y
  apt-get install xauth -y
  apt-get install xserver-xorg xserver-xorg-core -y
  apt-get install openbox -y
  ;;
  *)
  echo "Os not found, exiting...."
  exit 1
  ;;
esac


[[ ! -f /etc/ssh/ssh_config ]] && touch /etc/ssh/ssh_config
grep -q "#ForwardX11 yes" /etc/ssh/ssh_config
i=$?
if [[ $i = 0 ]]; then
  sed -i 's/.*ForwardX11.*/ForwardX11 yes/g' /etc/ssh/ssh_config
else
  grep -q "ForwardX11 yes" /etc/ssh/ssh_config
  i=$?
  if [[ $i = 0 ]]; then
    echo "/etc/ssh_config already has X11 Forward"
  else
    grep -q "Host *" /etc/ssh/ssh_config
    i=$?
    if [[ $i = 0 ]]; then
      echo "ForwardX11 yes" >> /etc/ssh/ssh_config
    else
      echo "Host *" >> /etc/ssh/ssh_config
      echo "ForwardX11 yes" >> /etc/ssh/ssh_config
    fi
  fi
fi

[[ ! -f /etc/ssh/sshd_config ]] && touch /etc/ssh/sshd_config
if [[ ! "$(ps -aux | grep -c cfengine)" -ge 2 ]]; then
  grep -q "X11Forwarding no" /etc/ssh/sshd_config
  i=$?
  if [[ $i = 0 ]]; then
    sed -i 's/.*X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config
  fi
  grep -q "#X11Forwarding yes" /etc/ssh/sshd_config
  i=$?
  if [[ $i = 0 ]]; then
    sed -i 's/.*X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config
  fi
  grep -q "X11UseLocalhost yes" /etc/ssh/sshd_config
  i=$?
  if [[ $i = 0 ]]; then
    sed -i 's/.*X11UseLocalhost.*/X11UseLocalhost no/g' /etc/ssh/sshd_config
  fi
  grep -q "#X11UseLocalhost no" /etc/ssh/sshd_config
  i=$?
  if [[ $i = 0 ]]; then
    sed -i 's/.*X11UseLocalhost.*/X11UseLocalhost no/g' /etc/ssh/sshd_config
  fi
else
  echo "Cfengine managed server, skipping /etc/ssh/sshd_config edit"
fi


cat << 'EOF' > /home/tibco/.bash_logout
#!/bin/bash
# ~/.bash_logout
tty=$(echo $DISPLAY | awk -F ":" '{ print $2 }' | awk -F "." '{ print ":" $1 }')
todel=$(xauth list | grep $tty | awk '{ print $1 }')
xauth remove $todel
EOF

cat << 'EOF' > /etc/profile.d/xauth.sh
##  /etc/profile.d/xauth.sh  ##
#!/bin/bash

 user=$(whoami)
 case $user in
 "tibco")
 tty=$(echo $DISPLAY | awk -F ":" '{ print $2 }' | awk -F "." '{ print ":" $1 }')
 vxauth=$(cat /tmp/xauth.tmp | grep "$tty")
 xauth add $vxauth
 ;;
 "root")
 ;;
 *)
 [[ ! -f /tmp/xauth.tmp ]] && touch /tmp/xauth.tmp && chmod 777 /tmp/xauth.tmp
 tty=$(echo $DISPLAY | awk -F ":" '{ print $2 }' | awk -F "." '{ print ":" $1 }')
 xauth list | grep "$tty" > /tmp/xauth.tmp
 ;;
esac
EOF


service sshd restart && service ssh restart
