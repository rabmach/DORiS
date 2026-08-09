#!/bin/bash

#MountPoint1=$(echo /dev/sda1)
#MountPoint2=$(echo /dev/sda2)
#MountPoint3=$(echo /dev/sda3)
#NetworkDevice1=$(echo enp0s25)

######## /settings

User=$(whoami)
Host=$(uname -n)
System=$(uname -s)
Release=$(uname -r)
Arch=$(uname -m)

#SizeMountPoint1=$(df -HlT | grep "$MountPoint1")
#SizeMountPoint2=$(df -HLT | grep "$MountPoint2")
#SizeMountPoint3=$(df -HlT | grep "$MountPoint3")
#SizeMountPoint4=$(df -HlT | grep "$MountPoint4")

#NetDev1ip=$(/sbin/ifconfig "$NetworkDevice1" | grep "inet addr:" | sed "s/.*inet addr://" | sed "s/Bcast.*//")
#NetDev1down=$(/sbin/ifconfig "$NetworkDevice1" | grep bytes | sed 's/.*RX bytes:[0-9]* (//'  | sed 's/iB).*TX.*//' | sed 's/b).*TX.*//' | sed 's/).*TX.*//')
#NetDev1up=$(/sbin/ifconfig "$NetworkDevice1" | grep bytes | sed 's/.*TX bytes:[0-9]* (//' | sed 's/iB)//' |sed 's/b).*//' | sed 's/).*//')

#NetDev2ip=$(/sbin/ifconfig "$NetworkDevice1" | grep "inet addr:" | sed "s/.*inet addr://" | sed "s/Bcast.*//")
#NetDev2down=$(/sbin/ifconfig "$NetworkDevice1" | grep bytes | sed 's/.*RX bytes:[0-9]* (//'  | sed 's/iB).*TX.*//' | sed 's/b).*TX.*//' | sed 's/).*TX.*//')
#NetDev2up=$(/sbin/ifconfig "$NetworkDevice1" | grep bytes | sed 's/.*TX bytes:[0-9]* (//' | sed 's/iB)//' |sed 's/b).*//' | sed 's/).*//')

DateDate=$(date '+Date ~ %Y.%m.%d. (%a)')
DateWeek=$(date '+Week ~ %W')
 DateDay=$(date '+ Day ~ %j')
DateTime=$(date '+Time ~ %H:%M [%Z]')
UpTime=$(uptime | sed 's/.* up //' | sed 's/[0-9]* us.*//' | sed 's/ day, /d/' | sed 's/ days, /d /' | sed 's/:/h /' | sed 's/ min//'|  sed 's/,/m/' | sed 's/  / /')

MemTotal=$(echo "scale = 2; ("$(cat /proc/meminfo | grep MemTotal: | awk '{print $2}' | sed 's/k//')" /1024)" | bc)
 MemFree=$(echo "scale = 2; ("$(cat /proc/meminfo | grep MemFree: | awk '{print $2}' | sed 's/k//')" /1024) + ("$(cat /proc/meminfo | grep -m 1 Cached: | awk '{print $2}' | sed 's/k//')" /1024)" | bc)
 MemUsed=$(echo "scale = 2; ("$(cat /proc/meminfo | grep MemTotal: | awk '{print $2}' | sed 's/k//')" /1024) - (("$(cat /proc/meminfo | grep MemFree: | awk '{print $2}' | sed 's/k//')" /1024) + ("$(cat /proc/meminfo | grep -m 1 Cached: | awk '{print $2}' | sed 's/k//')" /1024))" | bc)

SwpTotal=$(echo "scale = 2; ("$(cat /proc/meminfo | grep SwapTotal: | awk '{print $2}' | sed 's/k//')" /1024)" | bc)
 SwpFree=$(echo "scale = 2; ("$(cat /proc/meminfo | grep SwapFree: | awk '{print $2}' | sed 's/k//')" /1024)" | bc)
 SwpUsed=$(echo "scale = 2; ("$(cat /proc/meminfo | grep SwapTotal: | awk '{print $2}' | sed 's/k//')" /1024) - ("$(cat /proc/meminfo | grep SwapFree: | awk '{print $2}' | sed 's/k//')" /1024)" | bc)

MemUsedPercent=$(echo "scale = 2; (("$(cat /proc/meminfo | grep MemTotal: | awk '{print $2}' | sed 's/k//')" /1024) - (("$(cat /proc/meminfo | grep MemFree: | awk '{print $2}' | sed 's/k//')" /1024) + ("$(cat /proc/meminfo | grep -m 1 Cached: | awk '{print $2}' | sed 's/k//')" /1024))) / ("$(cat /proc/meminfo | grep MemTotal: | awk '{print $2}' | sed 's/k//')" /1024) *100" | bc)
if [ "${SwpTotal/.*}" != "0" ] && [ -n "$SwpTotal" ]; then
  SwpUsedPercent=$(echo "scale = 2; (("$(cat /proc/meminfo | grep SwapTotal: | awk '{print $2}' | sed 's/k//')" /1024) - ("$(cat /proc/meminfo | grep SwapFree: | awk '{print $2}' | sed 's/k//')" /1024)) / ("$(cat /proc/meminfo | grep SwapTotal: | awk '{print $2}' | sed 's/k//')" /1024) *100" | bc)
else
  SwpUsedPercent="n/a"
fi

CPUmodel=$(cat /proc/cpuinfo | grep "model name" | sed 's/.*: //')
CPUfreq=$(cat /proc/cpuinfo | grep -m 1 "cpu MHz" | sed 's/.*: //')
CPUcache=$(cat /proc/cpuinfo | grep -m 1 "cache size" | sed 's/.*: //')


echo "<openbox_pipe_menu>"
echo "<separator label=\"$User @ $Host \"/>"
echo "<item label=\"$System $Release $Arch\"/>"

#echo "<separator label = \"Filesystem ~~ Type ~~ Total ~ Used ~ Free ~ % ~ Mount   \"/>"
#echo "<item label=\"$SizeMountPoint1\"/>"
#echo "<item label=\"$SizeMountPoint2\"/>"
#echo "<item label=\"$SizeMountPoint3\"/>"


echo "<separator label=\"CPU ~ RAM ~ Swap | Used/Total     \"/>"
echo "<item label=\"RAM used: $MemUsed MiB/$MemTotal MiB ~ $MemUsedPercent%\"/>"
echo "<item label=\"Swp used: $SwpUsed MiB/$SwpTotal MiB ~ $SwpUsedPercent%\"/>"
echo "<item label=\"CPU ~ $CPUmodel\"/>"
echo "<item label=\"CPU @ $CPUfreq MHz  ~  CPU Cache: $CPUcache\"/>"

#echo "<separator label = \"Network ~ "$NetworkDevice1"  \"/>"
#echo "<item label=\""$NetworkDevice1" ~         ip: $NetDev1ip\"/>"
#echo "<item label=\""$NetworkDevice1" ~ downloaded: "$NetDev1down"iB\"/>"
#echo "<item label=\""$NetworkDevice1" ~   uploaded: "$NetDev1up"iB\"/>"

echo "<separator label = \"Date ~ Time\"/>"
echo "<item label=\"$DateDate\"/>"
echo "<item label=\"$DateWeek\"/>"
echo "<item label=\"$DateDay\"/>"
echo "<item label=\"$DateTime\"/>"
echo "<item label=\"  Up ~ $UpTime\"/>"

echo "</openbox_pipe_menu>"
