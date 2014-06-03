#!/bin/sh

#
#ardrone2 autoconnect 2 configured wpa2 network
# if it fails, go back to standard mode by calling /bin/wifi_setup.sh
# before running/activating this script:
# 	https://github.com/daraosn/ardrone-wpa2
# 	copy wpa_supplicant binaries to ardrone 
# 	configure wpa_supplicant.conf 
#
#only tested with firmware 2.4.8

#check if there is a wpa_supplicant.conf with non zero size. if not exit
if [ ! -e "/etc/wpa_supplicant.conf" ]
then
  echo "no wpa_supplicant.conf found. exiting"
  exit 2
fi

#grep wannted ssid from previously installed wpa_supplicant.conf
ESSID=`grep ssid /etc/wpa_supplicant.conf | awk -F\= '{gsub(/"/,"",$2);print $2}'`

#very important - we dont want a drone to play dhcpd on our wpa network...
#sleep 60
#wait for udhcpd to come up then kill it (it's started from backgroundscript /bin/wifi_setup.sh
#otherwise the drone will act as dhcpserver on the network which is very bad for other drones/hosts in the same network 
COUNT=`expr 0`
echo ""
while true; do

  COUNT=`expr $COUNT + 1`
  
  if [ $COUNT -gt 60 ];
  then
    echo "waited for 60 secs for dhcpd to come up. exiting kill loop."
    break
  fi

  PSOUT=`ps -w | grep -v grep`
  #if echo $PSOUT | grep -q "udhcpd"
  #echo `ps -w | grep -v grep` | grep "udhcpd"
  if echo `ps -w | grep -v grep` | grep -q "udhcpd";
  then
    killall -KILL udhcpd
    echo ""
    echo "udhcpd finally killed. continuing autoconnect script"
    echo ""
    break
  fi
  echo -n "."
  sleep 1
  
done
echo ""

#devel only: (if i ran the script before...)
killall -KILL udhcpc
killall -KILL wpa_supplicant

#check if we are already in that network
IWCONFIGOUT=`iwconfig ath0`
if echo $IWCONFIGOUT | grep -q $ESSID
then
  #we are already connected to the essid we want. do nothing
  echo "already connected to essid: $ESSID"
  exit 0
fi

#interface does not support scanning.... :(
#NETWORKS=`iwlist ath0 scanning`

#grep ssid /etc/wpa_supplicant.conf | awk -F\= '{gsub(/"/,"",$2);print $2}'
#if echo $NETWORKS | grep -q $ESSID;
#then
echo "trying to join network $ESSID"
#DHCPC="; wait 5; /sbin/udhcpc -i ath0"
#ADDRESS="0.0.0.0"
#IFCONFIG="ifconfig ath0 $ADDRESS"
#$IFCONFIG iwconfig ath0 essid '$ESSID' && wpa_supplicant -B -Dwext -iath0 -c/etc/wpa_supplicant.conf $DHCPC;
ifconfig ath0 0.0.0.0
iwconfig ath0 essid '$ESSID' && wpa_supplicant -B -Dwext -iath0 -c/etc/wpa_supplicant.conf
echo "iwconfig and wpa_supplicant done"
#echo "iwconfig ath0:"
#iwconfig ath0
#wait 5
sleep 2
#run in background we wait for lease below...
#FIXME reset wifi if no lease could be obtained
/sbin/udhcpc -b -i ath0
#$IFCONFIG; iwconfig ath0 essid '$ESSID' && wpa_supplicant -B -Dwext -iath0 -c/etc/wpa_supplicant.conf $DHCPC;

#now we should/could be connected or soonish...

#check if we are connected now
echo "waiting 10 secs to check if it worked"
sleep 10	
echo "iwconfig:"
iwconfig ath0
echo "ifconfig:"
ifconfig ath0
IFCONFIGOUT=`ifconfig ath0`
if echo $IFCONFIGOUT | grep -q "inet addr"
then
  #everything fine we have an IP address
  IP=`ifconfig ath0 | grep "inet addr"`
  echo "SUCCESS - got inet addr: $IP"
  exit 0
else
  #didnt work - reset wifi
  echo "something didnt work - calling /bin/wifi_setup.sh"
  killall -KILL wpa_supplicant
  /bin/wifi_setup.sh
fi

