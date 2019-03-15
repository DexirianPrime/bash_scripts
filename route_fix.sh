#!/bin/bash

#Check Linux Type

[[ -f /etc/redhat-release ]] && os=rh && echo "RH system found"
[[ -f /etc/debian_version ]] && os=deb && echo "Debian system found"
echo $os

subnet=$(route | grep default | awk '{ print $2 }' | awk -F "." '{ print $3 }')
dc=$(route | grep default | awk '{ print $2 }' | awk -F "." '{ print $2 }')
iface=$(route | grep default | awk '{ print $8 }')

[[ "$(ps -aux | grep -c cfengine)" -ge 2 ]] && echo "CFEngine managed server! Exiting script." && exit 1

case "$subnet" in
  210|212|214|216|218)
  echo "Checking active routes..."
  route | grep 172.19.113.0 > /dev/null
  grepcode=$?
  if [[ $grepcode = 0 ]]; then
     echo "Route already found, $HOSTNAME is ok"
   else
     echo "Route missing on $HOSTNAME, adding"
     route add -net 172.19.113.0 netmask 255.255.255.0 gw 172.$dc.$subnet.4
   fi
   echo "Scanning network config files"
   if [[ $os = "rh" ]]; then
     [[ ! -f /etc/sysconfig/network-scripts/route-$iface ]] && touch /etc/sysconfig/network-scripts/route-$iface
     grep 172.19.113.0 /etc/sysconfig/network-scripts/route-$iface > /dev/null
     grepcode=$?
     if [[ $grepcode = 0 ]]; then
        echo "Route exists in /etc/sysconfig/network-scripts/route-$iface, exiting..."
        exit 0
      else
        echo "Route not found, appending..."
        echo "172.19.113.0/24 via 172.$dc.$subnet.4 dev $iface" >> /etc/sysconfig/network-scripts/route-$iface
        echo "Route added to config, exiting..."
        exit 0
      fi
   fi
   if [[ $os = "deb" ]]; then
     grep 172.19.113.0 /etc/network/interfaces > /dev/null
     grepcode=$?
     if [[ $grepcode = 0 ]]; then
       echo "Route exists in /etc/network/interfaces, exiting..."
       exit 0
     else
       echo "Route not found, appending..."
       echo "up route add -net 172.19.113.0 netmask 255.255.255.0 gw 172.$dc.$subnet.4" >> /etc/network/interfaces
       echo "Route added to config, exiting..."
       exit 0
     fi
   else
     echo "OS Not supported, sorry"
     exit 0

   fi

  ;;
  *)
  echo "This subnet ($subnet) doesnt require specific route on $HOSTNAME"
  ;;
esac
