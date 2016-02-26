#!/bin/bash
# Copyright (C) 2015 AppexNetworks
# Author:	Len
# Date:		Oct, 2015
# Version:	1.5.10.13
#
# chkconfig: 2345 20 15
# description: ServerSpeeder, accelerate your network
#
### BEGIN INIT INFO
# Provides: ServerSpeeder
# Required-Start: $network
# Required-Stop:
# Default-Start: 2 3 5
# Default-Stop: 0 1 6
# Description: Start ServerSpeeder daemon.
### END INIT INFO

[ -w / ] || {
	echo "You are not running ServerSpeeder as root. Please rerun as root" >&2
	exit 1
}

ROOT_PATH=/serverspeeder
SHELL_NAME=serverSpeeder.sh
PRODUCT_NAME=ServerSpeeder
PRODUCT_ID=serverSpeeder

[ -f $ROOT_PATH/etc/config ] || { echo "Missing config file: $ROOT_PATH/etc/config" >&2; exit 1; }
. $ROOT_PATH/etc/config 2>/dev/null

getCpuNum() {
	[ $usermode -eq 1 ] && {
		CPUNUM=1
		return
	}
	[ $VER_STAGE -eq 1 ] && {
		CPUNUM=1
		return
	}
	local num=$(cat /proc/stat | grep cpu | wc -l)
	local X86_64=$(uname -a | grep -i x86_64)
	
	if [ $VER_STAGE -ge 4 -a -n "$cpuID" ]; then
		CPUNUM=$(echo $cpuID | awk -F, '{print NF}')
	else
		CPUNUM=$(($num - 1))
		[ -n "$engineNum" ] && {
			[ $engineNum -gt 0 -a $engineNum -lt $num ] && CPUNUM=$engineNum
		}
	
		[ -z "$X86_64" -a $CPUNUM -gt 4 ] && CPUNUM=4
	fi
	[ -n "$1" -a -n "$X86_64" -a $CPUNUM -gt 4 ] && {
		local memTotal=$(cat /proc/meminfo | awk '/MemTotal/ {print $2}')
		local used=$(($CPUNUM * 800000)) #800M
		local left=$(($memTotal - $used))
		[ $left -lt 2000000 ] && {
			echo -en "$HL_START"
			echo "$PRODUCT_NAME Warning: $CPUNUM engines will be launched according to the config file. Your system's total RAM is $memTotal(KB), which might be insufficient to run all the engines without performance penalty under extreme network conditions. "
			echo -en "$HL_END"
		}
	}
}

function unloadModule() {
	lsmod | grep "appex$1 " >/dev/null && rmmod appex$1 2>/dev/null
}

userCancel() {
	echo
	pkill -0 $KILLNAME 2>/dev/null
	[ $? -ne 0 ] && exit 0
	
	getCpuNum
	for enum in $(seq $CPUNUM); do
		freeIf $((enum - 1))
	done
	
	pkill $KILLNAME
	for i in $(seq 30); do
		pkill -0 $KILLNAME
		[ $? -gt 0 ] && break
		sleep 1
		[ $i -eq 6 ] && echo 'It takes a long time than usual, please wait for a moment...'
		[ $i -eq 30 ] && pkill -9 $KILLNAME
	done
	
	local enum=0
	for enum in $(seq $CPUNUM); do
		unloadModule $((enum - 1))
	done
	[ -f $OFFLOAD_BAK ] && {
		chmod +x $OFFLOAD_BAK && /bin/bash $OFFLOAD_BAK 2>/dev/null
	}
	[ -f /var/run/$PRODUCT_ID.pid ] && {
		kill -9 $(cat /var/run/$PRODUCT_ID.pid)
		rm -f /var/run/$PRODUCT_ID.pid
	}
}

function activate() {
	local activate
	echo "$PRODUCT_NAME is not activated."
	printf "You can register an account from ${HL_START}http://$HOST${HL_END}\n"
	echo -en "If you have account already, type ${HL_START}y${HL_END} to continue: [y/n]"
	read activate
	[ $activate = 'y' -o $activate = 'Y' ] && $ROOT_PATH/bin/activate.sh
}

function configCPUId() {
	local eth=$accif
	[ -z "$eth" ] && return
	# if there are 2 or more acc interfaces, assemble RE for awk
	[ $(echo $eth | wc -w) -gt 1 ] && eth=$(echo $eth | tr ' ' '|')
	local intAffinities=0
	local selectedPhysicalCpu=''
	local pBitmask
	local match
	local matchedPhysicalCpu
	local suggestCpuID=''
	# if cpuID has been specified, return
	[ -n "$cpuID" ] && return
	local physicalCpuNum=$(cat /proc/cpuinfo | grep 'physical id' | sort | uniq | wc -l)
	[ $physicalCpuNum -eq 0 ] && {
		echo -en "$HL_START"
		echo "$PRODUCT_NAME Warning: failed to detect physical CPU info, option 'detectInterrupt' will be ignored."
		echo -en "$HL_END"
		return
		#which dmidecode>/dev/null 2>&1 && dmidecode | grep -i product | grep 'VMware Virtual' >/dev/null &&
	}
	# if there's only one physical cpu, return
	[ $physicalCpuNum -eq 1 ] && return
	local processorNum=$(cat /proc/cpuinfo | grep processor | wc -l)
	local processorNumPerCpu=$(($processorNum / $physicalCpuNum))
	
	local affinities=$(cat /proc/interrupts  | awk -v eth="(${eth}).*TxRx" ' {if($NF ~ eth) {sub(":", "", $1); print $1}}')
	local val
	for affinity in $affinities; do
	    [ -f /proc/irq/$affinity/smp_affinity ] && {
	        val=$(cat /proc/irq/$affinity/smp_affinity | sed -e 's/^[0,]*//')
	        [ -n "$val" ] && intAffinities=$((0x$val | $intAffinities))
	    }
	done
	[ $intAffinities -eq 0 ] && return
	
	for processor in $(seq 0 $processorNum); do
	    pBitmask=$((1 << $processor))
	    match=$(($pBitmask & $intAffinities))
	    [ $match -gt 0 ] && {
	        #matchedPhysicalCpu=$(($processor / $processorNumPerCpu))
			matchedPhysicalCpu=$(cat /proc/cpuinfo | grep 'physical id' | awk -v row=$processor -F: ' NR == row + 1 {print $2}')
			matchedPhysicalCpu=$(echo $matchedPhysicalCpu)
	        [  -z "$selectedPhysicalCpu" ] && selectedPhysicalCpu=$matchedPhysicalCpu
	        # if nic interrupts cross more than one physical cpu, return
	        [ $selectedPhysicalCpu -ne $matchedPhysicalCpu ] && return
	        [ -n "$suggestCpuID" ] && suggestCpuID="${suggestCpuID},"
	        suggestCpuID="${suggestCpuID}${processor}"
	    	[ $engineNum -gt 0 ] && {
	    		[ $(echo $suggestCpuID | tr ',' ' ' | wc -w) -ge $engineNum ] && continue
	    	}
	    }
	done
	[ -z $suggestCpuID ] && return
	cpuID=$suggestCpuID
}

initConf() {
	HL_START="\033[37;40;1m"
	HL_END="\033[0m"
	OFFLOAD_BAK=$ROOT_PATH/etc/.offload
	RUNCONFIG_BAK=$ROOT_PATH/etc/.runconfig
	CPUNUM=0
	VER_STAGE=1
	HOST=dl.serverspeeder.com
	trap "userCancel;" 1 2 3 6 9 15

	local rst=0
	[ -n "$accif" ] && accif=$(echo $accif)
		
	[ -z "$acc" ] && acc=1
	[ -z "$advacc" ] && advacc=1
	[ -z "$advinacc" ] && advinacc=0

	[ -z "$csvmode" ] && csvmode=0
	[ -z "$highcsv" ] && highcsv=0
	[ -z "$subnetAcc" ] && subnetAcc=0
	[ -z "$maxmode" ] && maxmode=0
	[ -z "$maxTxEffectiveMS" ] && maxTxEffectiveMS=0
	[ -z "$shaperEnable" ] && shaperEnable=1
	[ -z "$accppp" ] && accppp=0
	[ -n "$byteCache" ] && byteCacheEnable=$byteCache
	[ -z "$byteCacheEnable" ] && byteCacheEnable=0
	[ "$byteCache" = "1" ] && byteCacheEnable=1
	[ -z "$dataCompEnable" ] && {
		if [ $byteCacheEnable -eq 0 ]; then
			dataCompEnable=0
		else
			dataCompEnable=1
		fi
	}
	[ -n "$httpComp" ] && httpCompEnable=$httpComp
	[ -z "$httpCompEnable" ] && httpCompEnable=1
	[ $byteCacheEnable -eq 1 -a -z "$byteCacheMemory" ] && {
		echo "ERROR(CONFIG): missing config: byteCacheMemory"
		rst=1
	}
	[ $byteCacheEnable -eq 1 ] && {
		[ -n "$diskDev" -a -d "$diskDev" ] && {
			echo "ERROR(CONFIG): diskDev should be a file"
			rst=1
		}
	} 
	
	[ -z "$packetWrapper" ] && packetWrapper=256
	[ -z "$byteCacheDisk" ] && byteCacheDisk=0
	[ -z "$txcsum" ] && txcsum=0
	[ -z "$rxcsum" ] && rxcsum=0
	[ -z "$pcapEnable" ] && pcapEnable=0
	[ -z "$bypassOverFlows" ] && bypassOverFlows=0
	[ -z "$initialCwndWan" ] && initialCwndWan=18
	[ -z "$tcpFlags" ] && tcpFlags=0x0
	[ -z "$shortRttMS" ] && shortRttMS=15
	
	[ -z "$licenseGen" ] && licenseGen=0
	[ -z "$usermode" ] && usermode=0
	[ -z "$accpath" ] && accpath="/proc/net/appex"
	[ -z "$dropCache" ] && dropCache="0"
	[ -z "$shrinkOSWmem" ] && shrinkOSWmem="0"
	[ -z "$apxexe" ] && {
		echo "ERROR(CONFIG): missing config: apxexe"
		rst=1
	}
	if [ -z "$apxlic" ]; then
		if [ -f $ROOT_PATH/bin/activate.sh ]; then
			#not actived
			rst=2
		else
			echo "ERROR(CONFIG): missing config: apxlic"
			rst=1
		fi
	fi
	if [ -f $apxexe ]; then
		KILLNAME=$(echo $(basename $apxexe) | sed "s/-\[.*\]//")
		[ -z "$KILLNAME" ] && KILLNAME="acce-";
	else
		echo "ERROR(CONFIGFILE): missing file: $apxexe"
		rst=1
	fi

	# Locate ethtool
	ETHTOOL=$(which ethtool)
	[ "$gso" != "1" -o "$rsc" != 1 ] && [ -z "$ETHTOOL" ] && {
		[ -f $ROOT_PATH/bin/ethtool ] && {
			ETHTOOL=$ROOT_PATH/bin/ethtool
		} || {
			echo 'ERROR(ETHTOOL): "ethtool" not found, please install "ethtool" using "yum install ethtool" or "apt-get install ethtool" according to your linux distribution'
			rst=1
		}
	}
	[ -z "$afterLoad" ] && afterLoad=/appex/bin/afterLoad
	[ "$detectInterrupt" = "1" ] && configCPUId
	[ $rst -eq 1 ] && exit 1
	return $rst
}

ip2long() {
  local IFS='.'
  read ip1 ip2 ip3 ip4 <<<"$1"
  echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4))
  #echo "$ip1 $ip2 $ip3 $ip4"
}

getVerStage() {
	local verName=$(echo $apxexe | awk -F- '{print $2}')
	local intVerName=$(ip2long $verName)
	local boundary=0
	
	boundary=$(ip2long '3.11.19.11')
	[ $intVerName -ge $boundary ] && {
		#mpoolMaxCache
		VER_STAGE=28
		return
	}
	
	boundary=$(ip2long '3.11.10.0')
	[ $intVerName -ge $boundary ] && {
		#synRetranMS
		VER_STAGE=26
		return
	}
	
	boundary=$(ip2long '3.11.9.1')
	[ $intVerName -ge $boundary ] && {
		#ipHooks
		VER_STAGE=24
		return
	}
	
	boundary=$(ip2long '3.11.5.1')
	[ $intVerName -ge $boundary ] && {
		#Azure support
		VER_STAGE=22
		return
	}
	
	boundary=$(ip2long '3.10.66.30')
	[ $intVerName -ge $boundary ] && {
		#dropCache
		VER_STAGE=20
		return
	}
	
	boundary=$(ip2long '3.10.66.21')
	[ $intVerName -ge $boundary ] && {
		#move shortRtt to cmd
		VER_STAGE=19
		return
	}
	
	boundary=$(ip2long '3.10.66.18')
	[ $intVerName -ge $boundary ] && {
		#add acc/noacc parameter to shortRttBypass
		VER_STAGE=17
		return
	}
	
	boundary=$(ip2long '3.10.66.16')
	[ $intVerName -ge $boundary ] && {
		#support specify key generate method
		VER_STAGE=16
		return
	}
	
	boundary=$(ip2long '3.10.66.6')
	[ $intVerName -ge $boundary ] && {
		#support kernel module options
		VER_STAGE=15
		return
	}
	
	boundary=$(ip2long '3.10.65.3')
	[ $intVerName -ge $boundary ] && {
		#add udptun for vxlan
		VER_STAGE=14
		return
	}
	
	boundary=$(ip2long '3.10.62.0')
	[ $intVerName -ge $boundary ] && {
		#free wanIf when wanIf down
		VER_STAGE=13
		return
	}
	
	boundary=$(ip2long '3.10.61.0')
	[ $intVerName -ge $boundary ] && {
		#add acc/noacc parameter to lanSegment 
		VER_STAGE=12
		return
	}
	
	boundary=$(ip2long '3.10.54.2')
	[ $intVerName -ge $boundary ] && {
		#suport taskSchedDelay tobe set to '0 0'
		VER_STAGE=11
		return
	}
	
	boundary=$(ip2long '3.10.45.0')
	[ $intVerName -ge $boundary ] && {
		#suport highcsv
		VER_STAGE=10
		return
	}

	boundary=$(ip2long '3.10.39.8')
	[ $intVerName -ge $boundary ] && {
		#added short-rtt gso rsc
		VER_STAGE=9
		return
	}

	boundary=$(ip2long '3.10.37.0')
	[ $intVerName -ge $boundary ] && {
		#added minSsThresh dbcRttThreshMS smMinKbps in config
		VER_STAGE=8
		return
	}

	boundary=$(ip2long '3.10.23.1')
	[ $intVerName -ge $boundary ] && {
		#added ultraBoostWin
		VER_STAGE=7
		return
	}

	boundary=$(ip2long '3.9.10.43')
	[ $intVerName -ge $boundary ] && {
		#added smBurstMS
		VER_STAGE=6
		return
	}

	boundary=$(ip2long '3.9.10.34')
	[ $intVerName -ge $boundary ] && {
		#support output session restriction msg
		VER_STAGE=5
		return
	}

	boundary=$(ip2long '3.9.10.30')
	[ $intVerName -ge $boundary ] && {
		#support specify cpuid
		VER_STAGE=4
		return
	}

	boundary=$(ip2long '3.9.10.23')
	[ $intVerName -ge $boundary ] && {
		#support 256 interfaces
		VER_STAGE=3
		return
	}

	boundary=$(ip2long '3.9.10.10')
	[ $intVerName -ge $boundary ] && {
		#support multiple cpu
		VER_STAGE=2
		return
	}
}

bakOffload() {
	[ -s $OFFLOAD_BAK ] && {
		sed -i "1 i $ETHTOOL -K $1 $2 $3 2>/dev/null" $OFFLOAD_BAK
	} || {
		echo "$ETHTOOL -K $1 $2 $3 2>/dev/null" > $OFFLOAD_BAK
	}
}

initConfigEng() {
	[ $usermode -eq 0 ] && {
		local tcp_wmem=$(set $shrinkOSWmem; echo $1)
		local wmem_max=$(set $shrinkOSWmem; echo $2)
		[ $acc -eq 1 ] && {
			[ -f $RUNCONFIG_BAK ] && /bin/bash $RUNCONFIG_BAK 2>/dev/null
			cat /dev/null > $RUNCONFIG_BAK
			[ "$tcp_wmem" = "1" ] && {
				tcp_wmem=$(cat /proc/sys/net/ipv4/tcp_wmem)
				[ -n "$tcp_wmem" ] && echo "echo '$tcp_wmem' >/proc/sys/net/ipv4/tcp_wmem" >> $RUNCONFIG_BAK
				echo "${shrinkOSWmemValue:-4096 16384 32768}" > /proc/sys/net/ipv4/tcp_wmem
			}
			[ "$wmem_max" = "1" ] && {
				wmem_max=$(cat /proc/sys/net/core/wmem_max)
				[ -n "$wmem_max" ] && echo "echo '$wmem_max' >/proc/sys/net/core/wmem_max" >> $RUNCONFIG_BAK
				echo "${shrinkOSWmemMax:-32768}" > /proc/sys/net/core/wmem_max
			}
		}
		
		
	}	
}

checkTso() {
	[ $VER_STAGE -ge 9 -a -n "$gso" -a "$gso" = "1" ] && return 0
	[ -z "$($ETHTOOL -k $1 2>/dev/null | grep -E 'tcp.segmentation.offload:')" ] && return 0
	[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'tcp.segmentation.offload: off')" ] && return 0
	$ETHTOOL -K $1 tso off 2>/dev/null
	local ok=1
	for i in 1 2 ; do
		[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'tcp.segmentation.offload: off')" ] && {
			ok=0
			bakOffload $1 tso on
			break
		}
		sleep 1
		$ETHTOOL -K $1 tso off 2>/dev/null
	done
	return $ok
}

checkGso() {
	[ $VER_STAGE -ge 9 -a -n "$gso" -a "$gso" = "1" ] && return 0
	[ -z "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.segmentation.offload:')" ] && return 0
	[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.segmentation.offload: off')" ] && return 0
	$ETHTOOL -K $1 gso off 2>/dev/null
	local ok=1
	for i in 1 2 ; do
		[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.segmentation.offload: off')" ] && {
			ok=0
			bakOffload $1 gso on
			break
		}
		sleep 1
		$ETHTOOL -K $1 gso off 2>/dev/null
	done
	return $ok
}

checkGro() {
	[ $VER_STAGE -ge 9 -a -n "$rsc" -a "$rsc" = "1" ] && return 0
	[ -z "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.receive.offload:')" ] && return 0
	[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.receive.offload: off')" ] && return 0
	$ETHTOOL -K $1 gro off 2>/dev/null
	local ok=1
	for i in 1 2 ; do
		[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'generic.receive.offload: off')" ] && {
			ok=0
			bakOffload $1 gro on
			break
		}
		sleep 1
		$ETHTOOL -K $1 gro off 2>/dev/null
	done
	return $ok
}

checkLro() {
	[ $VER_STAGE -ge 9 -a -n "$rsc" -a "$rsc" = "1" ] && return 0
	[ -z "$($ETHTOOL -k $1 2>/dev/null | grep -E 'large.receive.offload:')" ] && return 0
	[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'large.receive.offload: off')" ] && return 0
	$ETHTOOL -K $1 lro off 2>/dev/null
	local ok=1
	for i in 1 2 ; do
		[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'large.receive.offload: off')" ] && {
			ok=0
			bakOffload $1 lro on
			break
		}
		sleep 1
		$ETHTOOL -K $1 lro off 2>/dev/null
	done
	return $ok
}

checkSg() {
	[ $VER_STAGE -ge 9 -a -n "$gso" -a "$gso" = "1" ] && return 0
	[ -z "$($ETHTOOL -k $1 2>/dev/null | grep -E 'scatter.gather:')" ] && return 0
	[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'scatter.gather: off')" ] && return 0
	$ETHTOOL -K $1 sg off 2>/dev/null
	for i in 1 2 ; do
		[ -n "$($ETHTOOL -k $1 2>/dev/null | grep -E 'scatter.gather: off')" ] && {
			bakOffload $1 sg on
			break
		}
		sleep 1
		$ETHTOOL -K $1 sg off 2>/dev/null
	done
}

checkChecksumming() {
	[ "x$txcsum" = "x1" ] && $ETHTOOL -K $1 tx on 2>/dev/null
	[ "x$txcsum" = "x2" ] && $ETHTOOL -K $1 tx off 2>/dev/null
	[ "x$rxcsum" = "x1" ] && $ETHTOOL -K $1 rx on 2>/dev/null
	[ "x$rxcsum" = "x2" ] && $ETHTOOL -K $1 rx off 2>/dev/null
}

checkInfOffload() {
	local x
	for x in $1; do
		local isBondingInf=0
		local isBridgedInf=0
		local isVlanInf=0
		#echo checking $x
		#check whether been checked
		eval offload_checked=\$offload_checked_${x//\./dot}
		[ -n "$offload_checked" ] && continue
		eval offload_checked_${x//\./dot}=1
		
		#check whether the interface is bridged
		if [ -z "$2" -a -d /sys/class/net/$x/brport ]; then
			isBridgedInf=1
			local siblings=$(ls /sys/class/net/$x/brport/bridge/brif)
			for be in $siblings; do
				checkInfOffload $be 1
				[ $? -gt 0 ] && return $?
			done
		fi
		
		#check whether the interface is a bonding interface
		if [ -f /proc/net/bonding/$x ] ; then
			isBondingInf=1
			local bondEth=$(cat /proc/net/bonding/$x | grep "Slave Interface" | awk '{print $3}')
			for be in $bondEth ; do
				checkInfOffload $be
				[ $? -gt 0 ] && return $?
			done
		fi

		#check whether the interface is a vlan interface
		local vlanIf=$x
		ip link show $vlanIf | grep $vlanIf@ >/dev/null && {
			vlanIf=$(ip link show $vlanIf | awk -F: '/@/ {print $2}')
			vlanIf=${vlanIf#*@}
			[ "$vlanIf" != "$x" -a -n "$vlanIf" -a -d /sys/class/net/$vlanIf ] && {
				isVlanInf=1
				checkInfOffload $vlanIf
				[ $? -gt 0 ] && return $?
			}
		}
		
		#[ $isBondingInf -eq 0 -a $isVlanInf -eq 0 ] && {
			checkTso $x
			[ $? -gt 0 ] && return 1
			checkGso $x
			[ $? -gt 0 ] && return 2
			checkGro $x
			[ $? -gt 0 ] && return 3
			checkLro $x
			[ $? -gt 0 ] && return 4
			checkSg $x
			checkChecksumming $x
		#}
	done
	
	return 0
}

setParam() {
	local e=$1
	local engine=$1
	local item=$2
	shift 2
	local value=$@
	local saved
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''

		for i in $(seq ${configTimeout:-15}); do
			[ -d $accpath$engine ] && break
			echo -n .
			sleep 1
		done
		[ ! -d $accpath$engine ] && {
			echo "Loading $PRODUCT_NAME failed: failed to load engine $e" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local path="$accpath$engine/$item"
		for i in $(seq ${configTimeout:-15}); do
			[ -f $path ] && break
			echo -n .
			sleep 1
		done
	
		[ ! -f $path ] && {
			echo "Loading $PRODUCT_NAME failed: failed to locate $path" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		echo "$value" > $path 2>/dev/null
		if [ "${value:0:1}" = '+' -o "${value:0:1}" = '-' ]; then
			return 0
		else
			for ii in 1 2 3; do
				saved=$(cat $path 2>/dev/null)
				[ "$value" = "$saved" ] && return 0
				echo -n .
				sleep 1
			done
		fi
	
		echo "Failed to write configuration: $path" >&2
	else
		$apxexe /$engine/$item="$value"
		if [ "${value:0:1}" = '+' -o "${value:0:1}" = '-' ]; then
			return 0
		else
			saved=$($apxexe /$engine/$item 2>/dev/null)
			[ "$value" = "$saved" ] && return 0
		fi
	
		echo "Failed to write configuration: /$engine/$item" >&2
	fi
	
	stop >/dev/null 2>&1
	exit 1
}

setCmd() {
	local e=$1
	local engine=$1
	local item=$2
	shift 2
	local value=$@
	local saved
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''
		value=$(echo $value)
	
		for i in $(seq ${configTimeout:-15}); do
			[ -d $accpath$engine ] && break
			echo -n .
			sleep 1
		done
		[ ! -d $accpath$engine ] && {
			echo "Loading $PRODUCT_NAME failed: failed to load engine $e" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local path="$accpath$engine/cmd"
		for i in $(seq ${configTimeout:-15}); do
			[ -f $path ] && break
			echo -n .
			sleep 1
		done
	
		[ ! -f $path ] && {
			echo "Loading $PRODUCT_NAME failed: failed to locate $path" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		echo "$item: $value" > $path 2>/dev/null
		
		# if item is lanSegment, do not check
		[ "$item" == "lanSegment" ] && return 0
		
		# if item is shortRttBypass, do not check
		[ "$item" == "shortRttBypass" ] && return 0
		
		for ii in 1 2 3; do
			saved=$(cat $path | awk -F': ' "/$item:/ {print \$2}")
			[ "$value" = "$saved" ] && return 0
			saved=$(cat $path | grep "$item:" | cut -d ' ' -f 2)
			[ "$value" = "$saved" ] && return 0
			echo -n .
			sleep 1
		done
	
		echo "Failed to write configuration: $path:$item" >&2
	else
		value=$(echo $value)
		$apxexe /$engine/cmd="$item $value"
	
		saved=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
		[ "$value" = "$saved" ] && return 0
		saved=$($apxexe /$engine/cmd | grep "$item:" | cut -d ' ' -f 2)
		[ "$value" = "$saved" ] && return 0
	
		echo "Failed to write configuration: /$engine/cmd/$item" >&2
	fi
	
	
	stop >/dev/null 2>&1
	exit 1
}

setCmdBitwiseOr() {
	local e=$1
	local engine=$1
	local item=$2
	local value=$3
	local saved
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''
		value=$(echo $value)
	
		for i in $(seq ${configTimeout:-15}); do
			[ -d $accpath$engine ] && break
			echo -n .
			sleep 1
		done
		[ ! -d $accpath$engine ] && {
			echo "Loading $PRODUCT_NAME failed: failed to load engine $e" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local path="$accpath$engine/cmd"
		for i in $(seq ${configTimeout:-15}); do
			[ -f $path ] && break
			echo -n .
			sleep 1
		done
	
		[ ! -f $path ] && {
			echo "Loading $PRODUCT_NAME failed: failed to locate $path" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local originVal=$(cat $path | awk -F': ' "/$item:/ {print \$2}")
		((originVal = $originVal | $value))
		echo "$item: $originVal" > $path 2>/dev/null
		for ii in 1 2 3; do
			saved=$(cat $path | awk -F': ' "/$item:/ {print \$2}")
			((saved = saved & $value))
			[ $saved -gt 0 ] && return 0
			echo -n .
			sleep 1
		done
	
		echo "Failed to write configuration: $path:$item" >&2
	else
		value=$(echo $value)
	
		local originVal=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
		((originVal = $originVal | $value))
		$apxexe /$engine/cmd="$item $originVal"
		
		saved=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
		((saved = saved & $value))
		[ $saved -gt 0 ] && return 0
	
		echo "Failed to write configuration: /$engine/cmd/$item" >&2
	fi
	
		
	stop >/dev/null 2>&1
	exit 1
}

setCmdBitwiseXOr() {
	local e=$1
	local engine=$1
	local item=$2
	local value=$3
	local saved
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''
		value=$(echo $value)
	
		for i in $(seq ${configTimeout:-15}); do
			[ -d $accpath$engine ] && break
			echo -n .
			sleep 1
		done
		[ ! -d $accpath$engine ] && {
			echo "Loading $PRODUCT_NAME failed: failed to load engine $e" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local path="$accpath$engine/cmd"
		for i in $(seq ${configTimeout:-15}); do
			[ -f $path ] && break
			echo -n .
			sleep 1
		done
	
		[ ! -f $path ] && {
			echo "Loading $PRODUCT_NAME failed: failed to locate $path" >&2
			stop >/dev/null 2>&1
			exit 1
		}
	
		local originVal=$(cat $path | awk -F': ' "/$item:/ {print \$2}")
		((bitwiseAndVal = $originVal & $value))
		[ $bitwiseAndVal -eq 0 ] && return 0
		((originVal = $originVal ^ $value))
		echo "$item: $originVal" > $path 2>/dev/null
		for ii in 1 2 3; do
			saved=$(cat $path | awk -F': ' "/$item:/ {print \$2}")
			((saved = saved & $value))
			[ $saved -eq 0 ] && return 0
			echo -n .
			sleep 1
		done
		
	else
		value=$(echo $value)
	
		local originVal=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
		((bitwiseAndVal = $originVal & $value))
		[ $bitwiseAndVal -eq 0 ] && return 0
		((originVal = $originVal ^ $value))
		$apxexe /$engine/cmd="$item $originVal"
		saved=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
		((saved = saved & $value))
		[ $saved -eq 0 ] && return 0
		
	fi
	
		

	echo "Failed to write configuration: $path:$item" >&2
	stop >/dev/null 2>&1
	exit 1
}

getParam() {
	local engine=$1
	local item=$2
	local value
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''
		value=$(cat $accpath$engine/$item 2>/dev/null)
	else
		value=$($apxexe /$engine/$item)
	fi
	echo $value
}

getCmd() {
	local engine=$1
	local item=$2
	local value
	
	if [ $usermode -eq 0 ]; then
		[ $engine -eq 0 ] && engine=''
		value=$(cat $accpath$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
	else
		value=$($apxexe /$engine/cmd | awk -F': ' "/$item:/ {print \$2}")
	fi
	echo $value
}

configEng() {
	local e=$1

	#disable host fairness, voip, p2p
	setParam $e 'hostFairEnable' 0
	setParam $e 'voipAccEnable' 0

	#setCmd $e p2pPriorities 1

	#enable shaper and set bw to 1Gbps
	setParam $e 'shaperEnable' 1
	setParam $e 'wanKbps' $wankbps
	setParam $e 'wanInKbps' $waninkbps
	setParam $e 'conservMode' $csvmode

	#set acc
	setParam $e 'tcpAccEnable' $acc

	#set subnet acc
	setParam $e 'subnetAccEnable' $subnetAcc

	#set advance acc
	setParam $e 'trackRandomLoss' $advacc

	#set advinacc
	setParam $e 'advAccEnable' $advinacc

	#set shaper
	setParam $e 'shaperEnable' $shaperEnable

	#set max win to 0 for wan and 60 for lan
	setCmd $e maxAdvWinWan 0
	setCmd $e maxAdvWinLan 60

	#set maxTxEnable
	setParam $e 'maxTxEnable' $maxmode
	[ "x$maxmode" = "x1" ] && {
		setParam $e 'trackRandomLoss' 1
		setCmd $e maxTxEffectiveMS $maxTxEffectiveMS
	}

	[ -n "$maxTxMinSsThresh" ] && setCmd $e maxTxMinSsThresh $maxTxMinSsThresh
	[ -n "$maxAccFlowTxKbps" ] && setCmd $e maxAccFlowTxKbps $maxAccFlowTxKbps
	#set pcapEnable
	setParam $e 'pcapEnable' $pcapEnable

	#set bypassOverFlows
	setCmd $e bypassOverFlows $bypassOverFlows
	#set initialCwndWan
	setCmd $e initialCwndWan $initialCwndWan
	#queue size limit for lan to wan 
	[ -n "$l2wQLimit" ] && setCmd $e l2wQLimit $l2wQLimit
	#queue size limit for wan to lan 
	[ -n "$w2lQLimit" ] && setCmd $e w2lQLimit $w2lQLimit
	#set halfCwndMinSRtt
	[ -n "$halfCwndMinSRtt" ] && setCmd $e halfCwndMinSRtt $halfCwndMinSRtt
	#set halfCwndLossRateShift
	[ -n "$halfCwndLossRateShift" ] && setCmd $e halfCwndLossRateShift $halfCwndLossRateShift
	#set retranWaitListMS
	[ -n "$retranWaitListMS" ] && setCmd $e retranWaitListMS $retranWaitListMS
	#set tcpOnly
	[ -n "$tcpOnly" ] && setCmd $e tcpOnly $tcpOnly

	#set smBurstMS [suported from 3.9.10.43]
	[ $VER_STAGE -ge 6 ] && {
		[ -n "$smBurstMS" ] && setCmd $e smBurstMS $smBurstMS
		[ -n "$smBurstTolerance" ] && setCmd $e smBurstTolerance $smBurstTolerance
		[ -n "$smBurstMin" ] && setCmd $e smBurstMin $smBurstMin
	}

	if [ $usermode -eq 0 ]; then
		#set shrinkPacket
		[ -n "$shrinkPacket" ] && setCmd $e shrinkPacket $shrinkPacket
		
		setParam $e 'byteCacheEnable' $byteCacheEnable
		#setCmd $e engine $(getCmd $e engine | awk '{print $1,$2}') $(($byteCacheMemory/6))
		
		setParam $e 'dataCompEnable' $dataCompEnable
		
		if [[ "$byteCacheEnable" == "1" || "$dataCompEnable" == "1" ]]; then
			setParam $e 'httpCompEnable' $httpCompEnable
		else
			setParam $e 'httpCompEnable' 0
		fi
		
		#from 3.10.39.8
		[ $VER_STAGE -ge 9 ] && { 
			[ -n "$rsc" ] && setCmd $e rsc $rsc
			[ -n "$gso" ] && setCmd $e gso $gso
		
			#only set shortRttMS for the first engine
			[ $VER_STAGE -lt 19 -a -z "$e" -a -n "$shortRttMS" -a "$shortRttMS" != "0" ] && setCmd $e shortRttMS $shortRttMS
		}
		
		if [ -n "$lanSegment" ]; then
			setCmd $e lanSegment $lanSegment
			saved=$(getCmd $e lanSegment)
			[[ ${saved#$lanSegment} == $saved && ${lanSegment#$saved} == $lanSegment ]] && {
				echo "Failed to write configuration: lanSegment" >&2
				stop >/dev/null 2>&1
				exit 1
			}
		else
			setCmd $e lanSegment ""
		fi
		
		#from 3.10.45.0
		[ $VER_STAGE -ge 10 ] && {
			[ -n "$txCongestObey" ] && setCmd $e txCongestObey $txCongestObey
			[[ -n "$highcsv" && $highcsv -gt 0 ]] && {
				setCmdBitwiseOr $e tcpFlags 0x4000
			} || {
				setCmdBitwiseXOr $e tcpFlags 0x4000
			}
		}
	fi

	#from 3.10.23.1
	[ $VER_STAGE -ge 7 -a -n "$ultraBoostWin" ] && setCmd $e ultraBoostWin $ultraBoostWin

	[ $VER_STAGE -ge 8 ] && {
		[ -n "$minSsThresh" ] && setCmd $e minSsThresh $minSsThresh
		[ -n "$dbcRttThreshMS" ] && setCmd $e dbcRttThreshMS $dbcRttThreshMS
		[ -n "$smMinKbps" ] && setCmd $e dbcRttThreshMS $smMinKbps
	}
	
	#from 3.10.54.2
	[ $VER_STAGE -ge 11 ] && {
		[ -n "$taskSchedDelay" ] && setCmd $e taskSchedDelay $taskSchedDelay
	}

	setCmd $e tcpFlags $tcpFlags

	#from 3.10.66.0
	[ $VER_STAGE -ge 14 ] && {
		[ -n "$udptun" ] && {
			setCmd $e udptun $udptun
		} || {
			setCmd $e udptun ''
		}
	}
	
	#from 3.10.66.18
	[ $VER_STAGE -ge 17 ] && {
		if [ -n "$shortRttBypass" ]; then
			setCmd $e shortRttBypass $shortRttBypass
			saved=$(getCmd $e shortRttBypass)
			[[ ${saved#$shortRttBypass} == $saved && ${shortRttBypass#$saved} == $shortRttBypass ]] && {
		        echo "Failed to write configuration: shortRttBypass" >&2
		        stop >/dev/null 2>&1
		        exit 1
			}
		else
			setCmd $e shortRttBypass ""
		fi
	}
	
	[ $usermode -eq 1 ] && setParam $e logDir $ROOT_PATH/log
	[ -n "$flowShortTimeout" ] && setCmd $e flowShortTimeout $flowShortTimeout
	[ $VER_STAGE -ge 19 ] && {
		setCmd $e shortRttMS $shortRttMS
		if [ -n "$shortRttMS" -a "$shortRttMS" != "0" ]; then
			setCmdBitwiseOr $e tcpFlags 0x800
		else
			setCmdBitwiseXOr $e tcpFlags 0x800
		fi
	}
	
	#from 3.11.10.0
	[ $VER_STAGE -ge 26 ] && {
		[ -n "$synRetranMS" ] && setCmd $e synRetranMS $synRetranMS
	}
	#from 3.11.19.11
	[ $VER_STAGE -ge 28 ] && {
		[ -n "$mpoolMaxCache" ] && setCmd $e mpoolMaxCache $mpoolMaxCache
	}

	local ee=$e
	[ $ee -eq 0 ] && ee=''
	[ -f /proc/net/appex${ee}/engSysEnable ] && setParam $e 'engSysEnable' 1
	
	#set acc interface
	if [ $VER_STAGE -lt 3 ]; then
		setParam $e 'wanIf' $accif
	else
		local tobeAdded tobeRemoved
		
		curWanIf=$(getParam $e wanIf)
		for aif in $accif; do
			[ "${curWanIf/$aif}" = "$curWanIf" ] && tobeAdded="$tobeAdded $aif"
		done
		for aif in $curWanIf; do
			[ "${accif/$aif}" = "$accif" ] && tobeRemoved="$tobeRemoved $aif"
		done
		
		tobeAdded=$(echo $tobeAdded)
		tobeRemoved=$(echo $tobeRemoved)
		
		[ -n "$tobeAdded" ] && {
			for x in $tobeAdded; do
				setParam $e 'wanIf' "+$x"
			done
		}
		[ -n "$tobeRemoved" ] && {
			for x in $tobeRemoved; do
				setParam $e 'wanIf' "-$x"
			done
		}
		
		local savedWanIf=$(getParam $e wanIf)
		for aif in $accif; do
			[ "${savedWanIf/$aif}" = "$savedWanIf" ] && {
				echo "Failed to write configuration: wanIf($aif)" >&2
		   		stop >/dev/null 2>&1
				exit 1
			}
		done
	fi
}

function freeIf() {
	[ $usermode -eq 1 ] && return
	local e=$1
	[ $e -eq 0 ] && e=''
	local epath="$accpath$e"
	[ -d $epath ] || return
	echo "" > $epath/wanIf 2>/dev/null
}

function disp_usage() {
	if [ $VER_STAGE -eq 1 ]; then
		echo "Usage: $0 {start | stop | reload | restart | status | renewLic | update | uninstall}"
	else
		echo "Usage: $0 {start | stop | reload | restart | status | stats | renewLic | update | uninstall}"
	fi
	echo
	echo -e "  start\t\t  start $PRODUCT_NAME"
	echo -e "  stop\t\t  stop $PRODUCT_NAME"
	echo -e "  reload\t  reload configuration"
	echo -e "  restart\t  restart $PRODUCT_NAME"
	echo -e "  status\t  show $PRODUCT_NAME running status"
	[ $VER_STAGE -gt 1 ] && echo -e "  stats\t\t  show realtime connection statistics"
	echo
	echo -e "  renewLic\t  update license file"
	echo -e "  update\t  update $PRODUCT_NAME"
	echo -e "  uninstall\t  uninstall $PRODUCT_NAME"
	exit 1
}

function init() {
	[ "$accppp" = "1" ] && {
		local updir=${pppup:- /etc/ppp/ip-up.d}
		local downdir=${pppdown:- /etc/ppp/ip-down.d}
		
		[ -d $updir ] && ln -sf $ROOT_PATH/bin/$SHELL_NAME $updir/pppup
		[ ! -f /etc/ppp/ip-up.local ] && ln -sf $ROOT_PATH/bin/$SHELL_NAME /etc/ppp/ip-up.local
		
		[ -d $downdir ] && ln -sf $ROOT_PATH/bin/$SHELL_NAME $downdir/pppdown
		[ ! -f /etc/ppp/ip-down.local ] && ln -sf $ROOT_PATH/bin/$SHELL_NAME /etc/ppp/ip-down.local
	}
}

function endLoad() {
	[ "$accppp" = "1" -a -f /proc/net/dev ] && {
		local updir=${pppup:- /etc/ppp/ip-up.d}
		[ -f $updir/pppup ] && {
			for i in $(cat /proc/net/dev | awk -F: '/ppp/ {print $1}'); do
				$updir/pppup $i
			done
		}
		[ -f /etc/ppp/ip-up.local ] && {
			for i in $(cat /proc/net/dev | awk -F: '/ppp/ {print $1}'); do
				/etc/ppp/ip-up.local $i
			done
		}
	}
}

function freeupLic() {
	local force=0
	[ "$1" = "-f" -o "$1" = "-force" ] && force=1
	echo 'connect to license server...'
	local url="http://$HOST/auth/free2.jsp?e=$email&s=$serial"
	wget --timeout=5 --tries=3 -O /dev/null $url >/dev/null 2>/dev/null
	[ $? -ne 0 -a $force -eq 0 ] && {
		echo 'failed to connect license server, please try again later.'
		echo -n "if you still want to uninstall $PRODUCT_NAME, please run "
		echo -en "$HL_START"
		echo -n "$0 uninstall -f"
		echo -e "$HL_END"
		exit 1
	}
}

function uninstall() {
	freeupLic $1
	[ -d "$accpath" ] && stop >/dev/null || {
		pkill -0 $KILLNAME 2>/dev/null
		[ $? -eq 0 ] && stop >/dev/null
	}
	sleep 2
	cd ~
	rm -rf $ROOT_PATH
	
	rm -f /etc/rc.d/init.d/$PRODUCT_ID 2>/dev/null
	rm -f /etc/rc.d/rc*.d/S20$PRODUCT_ID 2>/dev/null
	rm -f /etc/rc.d/$PRODUCT_ID 2>/dev/null
	rm -f /etc/rc.d/rc*.d/*$PRODUCT_ID 2>/dev/null
	rm -f /etc/init.d/$PRODUCT_ID 2>/dev/null
	rm -f /etc/rc*.d/S03$PRODUCT_ID 2>/dev/null
	
	rm -f /usr/lib/systemd/system/$PRODUCT_ID.service 2>/dev/null
	systemctl daemon-reload 2>/dev/null
		
	
	echo "Uninstallation done!"
	exit
}

function stop() {
	[ -d "$accpath" ] || {
		pkill -0 $KILLNAME 2>/dev/null
		[ $? -ne 0 ] && {
			echo "$PRODUCT_NAME is not running!" >&2
			exit 1
		}
	}
	
	if [ $usermode -eq 0 ]; then
		getCpuNum
		for enum in $(seq $CPUNUM); do
			freeIf $((enum - 1))
		done
		
		pkill $KILLNAME
		for i in $(seq 30); do
			pkill -0 $KILLNAME
			[ $? -gt 0 ] && break
			sleep 1
			[ $i -eq 6 ] && echo 'It takes a long time than usual, please wait for a moment...'
			[ $i -eq 30 ] && pkill -9 $KILLNAME
		done
		
		local enum=0
		for enum in $(seq $CPUNUM); do
			unloadModule $((enum - 1))
		done
		[ -f $OFFLOAD_BAK ] && /bin/bash $OFFLOAD_BAK 2>/dev/null
		[ -f $RUNCONFIG_BAK ] && {
			/bin/bash $RUNCONFIG_BAK 2>/dev/null
			rm -f RUNCONFIG_BAK 2>/dev/null
		}
	else
		$apxexe quit
	fi
		
	echo "$PRODUCT_NAME is stopped!"
}

function start() {
	[ -d "$accpath" ] && {
		echo "$PRODUCT_NAME is running!" >&2
		exit 1
	}
	pkill -0 $KILLNAME 2>/dev/null
	[ $? -eq 0 ] && {
		echo "$PRODUCT_NAME is running!"
		exit 1
	}
	
	if [ $usermode -eq 0 ]; then
		#disable tso&gso&sg
		cat /dev/null > $OFFLOAD_BAK
		checkInfOffload "$accif"
		case $? in
			1)
				echo "Can not disable tso(tcp segmentation offload) of $x, exit!"
				exit 1
				;;
			2)
				echo "Can not disable gso(generic segmentation offload) of $x, exit!"
				exit 1
				;;
			3)
				echo "Can not disable gro(generic receive offload) of $x, exit!"
				exit 1
				;;
			4)
				echo "Can not disable lro(large receive offload) of $x, exit!"
				exit 1
				;;
		esac
	fi
	
	init
	getCpuNum 1
	local engineNumOption="-n $CPUNUM"
	local shortRttOption=''
	local pmtuOption=''
	local kernelOption=''
	local keyOption=''
	local bcOption=''
	local dropCacheOption=''
	
	[ -n "$pmtu" ] && pmtuOption="-t $pmtu"
	[ "$byteCacheEnable" == "1" ] && {
		[ $byteCacheMemory -ge 0 ] && bcOption="-m $(($byteCacheMemory/2))"
		[ -n "$diskDev" -a $byteCacheDisk -ge 0 ] && bcOption=" $bcOption -d $(($byteCacheDisk/2)) -c $diskDev"
		bcOption=$(echo $bcOption)
		[ -n "$bcOption" ] && bcOption="-b $bcOption"
	}
	
	[ $VER_STAGE -ge 4 -a -n "$cpuID" ] && engineNumOption="-c $cpuID"
	[ $VER_STAGE -ge 9 -a -n "$shortRttMS" -a "$shortRttMS" != "0" ] && shortRttOption="-w $shortRttMS"
	[ $VER_STAGE -ge 19 ] && shortRttOption=''
	# 3.11.9.1
	[ $VER_STAGE -ge 24 -a -n "$ipHooks" ] && kernelOption="$kernelOption ipHooks=$ipHooks"
	[ $VER_STAGE -ge 15 ] && {
		[ -n "$ipRxHookPri" ] && kernelOption="$kernelOption ipRxHookPri=$ipRxHookPri"
		[ -n "$ipTxHookPri" ] && kernelOption="$kernelOption ipTxHookPri=$ipTxHookPri"
		[ -n "$kernelOption" ] && kernelOption=$(echo $kernelOption)
	}
	[ $VER_STAGE -ge 16 ] && keyOption="-K $licenseGen"
	[ $licenseGen -eq 5 -a $VER_STAGE -lt 22 ] && {
		echo 'please update acce vertion greater than 3.11.5.1'
		exit 1
	}
	[ $VER_STAGE -ge 20 -a -n "$dropCache" -a "$dropCache" != "0" ] && dropCacheOption="-r $dropCache"
	
	if [ $usermode -eq 0 ]; then
		$apxexe $keyOption $engineNumOption -s $apxlic -m -p $packetWrapper $pmtuOption $shortRttOption $dropCacheOption ${kernelOption:+-k "$kernelOption"} $bcOption
	else
		$apxexe -e -i $keyOption -s $apxlic -p $packetWrapper $pmtuOption $shortRttOption
	fi 
	[ $? -ne 0 ] && {
		echo "Load $PRODUCT_NAME failed!"
		exit $result
	}
	#sleep 1
	initConfigEng
	local enum=0
	while [ $enum -lt $CPUNUM ]; do
		configEng $enum
		enum=$(($enum + 1))
	done
	#[ -f $ROOT_PATH/bin/apxClsfCfg  -a -f $ROOT_PATH/etc/clsf ] && $ROOT_PATH/bin/apxClsfCfg 2>/dev/null
	endLoad
	[ $VER_STAGE -ge 9 -a -n "$shortRttMS" -a "$shortRttMS" != "0" ] && echo "Short-RTT bypass has been enabled"
}

function restart() {
	[ -d "$accpath" ] && stop >/dev/null || {
		pkill -0 $KILLNAME 2>/dev/null
		[ $? -eq 0 ] && stop >/dev/null
	}
	sleep 2
	start
}

function pppUp() {
	getCpuNum
	local eNum=0
	local e
	if [ $usermode -eq 0 ]; then
		while [ $eNum -lt $CPUNUM ]; do
			e=$eNum
			[ $e -eq 0 ] && e=''
			[ -d /proc/net/appex$e ] && {
				echo "$+$1" > /proc/net/appex$e/wanIf
			}
			((eNum = $eNum + 1))
		done
	else
		pkill -0 $KILLNAME 2>/dev/null
		[ $? -eq 0 ] || exit 0
		while [ $eNum -lt $CPUNUM ]; do
			$apxexe /$eNum/wanIf=+$1
			((eNum = $eNum + 1))
		done
	fi
	exit 0	
}

function pppDown() {
	getCpuNum
	local eNum=0
	local e
	if [ $usermode -eq 0 ]; then
		while [ $eNum -lt $CPUNUM ]; do
			e=$eNum
			[ $e -eq 0 ] && e=''
			[ -d /proc/net/appex$e ] && {
				curWanIf=$(getParam $eNum wanIf)
				setParam $eNum wanIf ''
				for cIf in $curWanIf; do
					[ $cIf != "$1" ] && setParam $eNum wanIf "+$cIf"
				done
			}
			((eNum = $eNum + 1))
		done
	else
		pkill -0 $KILLNAME 2>/dev/null
		[ $? -eq 0 ] || exit 0
		while [ $eNum -lt $CPUNUM ]; do
			$apxexe /$eNum/wanIf=-$1
			((eNum = $eNum + 1))
		done
	fi
	exit 0	
}

initConf
[ $? -eq 2 ] && {
	activate
	exit
}

getVerStage
bn=$(basename $0)
if [ "$bn" = "pppup" -o "$bn" = "ip-up.local" ]; then
	[ "$accppp" != "1" ] && exit 0
	pppUp $1
	exit 0
elif [ "$bn" = "pppdown" -o "$bn" = "ip-down.local" ]; then
	[ "$accppp" != "1" ] && exit 0
	pppDown $1
	exit 0
fi

[ -z $1 ] && disp_usage
[ -d /var/run ] || mkdir -p /var/run
[ -f /var/run/$PRODUCT_ID.pid ] && {
	pid=$(cat /var/run/$PRODUCT_ID.pid)
	kill -0 $pid 2>/dev/null
	[ $? -eq 0 ] && {
		echo "$SHELL_NAME is still running, please try again later"
		exit 2
	}
}
case "$1" in
	stop)
		echo $$ > /var/run/$PRODUCT_ID.pid
		stop
		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
		;;
	start)
		echo $$ > /var/run/$PRODUCT_ID.pid
		start
		[ -f $ROOT_PATH/bin/.debug.sh ] && $ROOT_PATH/bin/.debug.sh >/dev/null 2>&1 &
		[ -f $afterLoad ] && chmod +x $afterLoad && $afterLoad >/dev/null 2>&1 &
		sleep 1
		echo
		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
		;;
	reload)
		echo $$ > /var/run/$PRODUCT_ID.pid
		pkill -0 $KILLNAME 2>/dev/null || {
			start
			[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
			exit 0
		}
		#check whether accif is changed
		accIfChanged=0
		curWanIf=$(getParam 0 wanIf)
		[ ${#accif} -ne ${#curWanIf} ] && accIfChanged=1
		[ $accIfChanged -eq 0 ] && {
			for aif in $accif; do
				[ "${curWanIf/$aif}" = "$curWanIf" ] && {
					accIfChanged=1
					break
				}
			done
		}
		[ $accIfChanged -eq 1 -a $usermode -eq 0 ] && {
			[ -f $OFFLOAD_BAK ] && /bin/bash $OFFLOAD_BAK 2>/dev/null
			[ "$detectInterrupt" = "1" ] && {
				[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
				$0 restart
				exit
			}
			
			#disable tso&gso&sg
			cat /dev/null > $OFFLOAD_BAK
			checkInfOffload "$accif"
			case $? in
				1)
					echo "Can not disable tso(tcp segmentation offload) of $x, exit!" >&2
					exit 1
					;;
				2)
					echo "Can not disable gso(generic segmentation offload) of $x, exit!" >&2
					exit 1
					;;
				3)
					echo "Can not disable gro(generic receive offload) of $x, exit!" >&2
					exit 1
					;;
				4)
					echo "Can not disable lro(large receive offload) of $x, exit!" >&2
					exit 1
					;;
			esac
		}
		initConfigEng
		getCpuNum 1
		enum=0
		while [ $enum -lt $CPUNUM ]; do
			configEng $enum
			enum=`expr $enum + 1`
		done
		#[ -f $ROOT_PATH/bin/apxClsfCfg  -a -f $ROOT_PATH/etc/clsf ] && $ROOT_PATH/bin/apxClsfCfg 2>/dev/null
		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
		;;
	restart)
		echo $$ > /var/run/$PRODUCT_ID.pid
		restart
		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
		;;
   	status|st)
   		echo -en "$HL_START"
   		echo -n "[Running Status]"
   		echo -e "$HL_END"
   		pkill -0 $KILLNAME 2>/dev/null
   		if [ $? -eq 0 ];then
   			running=1
   			echo "$PRODUCT_NAME is running!"
   		else
   			running=0
   			echo "$PRODUCT_NAME is NOT running!"
   		fi
   		
		if [ $running -eq 1 -a $usermode -eq 1 ]; then
			printf "%-20s %s\n" version $(getParam 0 version)
		else
			verName=$(echo $apxexe | awk -F- '{print $2}')
			printf "%-20s %s\n" version $verName
		fi
		echo
   		
   		echo -en "$HL_START"
   		echo -n "[License Information]"
   		echo -e "$HL_END"
   		if [ $VER_STAGE -ge 5 ]; then
   			keyOption=''
   			[ $VER_STAGE -ge 16 ] && keyOption="-K $licenseGen"
   			if [ $usermode -eq 0 -a "$byteCacheEnable" == "1" ]; then
	   			$apxexe $keyOption -s $apxlic -d | while read _line; do
					echo $_line | awk -F': ' '/^[^\(]/{if($1 != "MaxCompSession"){printf "%-20s %s\n", $1, ($2 == "0" ? "unlimited" : $2)}}'
				done 2>/dev/null
			else
				$apxexe $keyOption -s $apxlic -d | while read _line; do
					echo $_line | awk -F': ' '/^[^\(]/{if($1 != "MaxCompSession" && $1 != "MaxByteCacheSession"){printf "%-20s %s\n", $1, ($2 == "0" ? "unlimited" : $2)}}'
				done 2>/dev/null
			fi
   		else
   			printf "%-20s %s\n" $(echo $apxlic | awk -F- '{printf "expiration %0d", $2}' )
   		fi
   		
   		if [ $running -eq 1 ];then
   			echo
   			echo -en "$HL_START"
	   		echo -n "[Connection Information]"
	   		echo -e "$HL_END"
	   		if [ $usermode -eq 0 ]; then
	   			cat /proc/net/appex*/stats 2>/dev/null | awk -F= '/NumOf.*Flows/ {gsub(/[ \t]*/,"",$1);gsub(/[ \t]*/,"",$2);a[$1]+=$2;} END {\
	   				printf "%-20s %s\n", "TotalFlow",a["NumOfFlows"];\
	   				printf "%-20s %s\n", "NumOfTcpFlows",a["NumOfTcpFlows"];\
	   				printf "%-20s %s\n", "TotalAccTcpFlow",a["NumOfAccFlows"];\
	   				printf "%-20s %s\n", "TotalActiveTcpFlow",a["NumOfActFlows"];\
	   			}'
	   		else
	   			$apxexe /0/stats | awk -F= '/NumOf.*Flows/ {gsub(/[ \t]*/,"",$1);gsub(/[ \t]*/,"",$2);a[$1]+=$2;} END {\
	   				printf "%-20s %s\n", "TotalFlow",a["NumOfFlows"];\
	   				printf "%-20s %s\n", "NumOfTcpFlows",a["NumOfTcpFlows"];\
	   				printf "%-20s %s\n", "TotalAccTcpFlow",a["NumOfAccFlows"];\
	   				printf "%-20s %s\n", "TotalActiveTcpFlow",a["NumOfActFlows"];\
	   			}'
	   		fi
	   		
	   		
	   		echo
	   		echo -en "$HL_START"
	   		echo -n "[Running Configuration]"
	   		echo -e "$HL_END"
			printf "%-20s %s %s %s %s %s %s %s %s\n" accif $(getParam 0 wanIf)
			printf "%-20s %s\n" acc $(getParam 0 tcpAccEnable)

			printf "%-20s %s\n" advacc $(getParam 0 trackRandomLoss)
			printf "%-20s %s\n" advinacc $(getParam 0 advAccEnable)
			printf "%-20s %s\n" wankbps $(getParam 0 wanKbps)
			printf "%-20s %s\n" waninkbps $(getParam 0 wanInKbps)
			printf "%-20s %s\n" csvmode $(getParam 0 conservMode)
			printf "%-20s %s\n" subnetAcc $(getParam 0 subnetAccEnable)
			printf "%-20s %s\n" maxmode $(getParam 0 maxTxEnable)
			printf "%-20s %s\n" pcapEnable $(getParam 0 pcapEnable)
			
			[ $usermode -eq 0 ] && {
				[ $VER_STAGE -ge 9 -a -n "$shortRttMS" -a "$shortRttMS" != "0" ] && printf "%-20s %s\n" shortRttMS $(getCmd 0 shortRttMS | awk '{print $1}')
				[ "$byteCacheEnable" == "1" ] && printf "%-20s %s\n" byteCacheEnable $(getParam 0 byteCacheEnable)
			}
   		fi
   		;;
   	stats)
   		[ $VER_STAGE -eq 1 ] && {
   			echo 'Not available for this version!'
   			exit 1
   		}
   		[ -f $ROOT_PATH/bin/utils.sh ] || {
   			echo "Missing $ROOT_PATH/bin/utils.sh"
   			exit 1
   		}
   		trap - 1 2 3 6 9 15
   		$ROOT_PATH/bin/utils.sh $2
   		;;
   	renewLic|renew)
   		echo $$ > /var/run/$PRODUCT_ID.pid
   		shift
   		. $ROOT_PATH/bin/renewLic.sh
   		renew $@
   		return_var=$?
   		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
   		exit $return_var
   		;;
   	update|up)
   		echo $$ > /var/run/$PRODUCT_ID.pid
   		shift
   		. $ROOT_PATH/bin/update.sh
   		update $@
   		return_var=$?
   		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
   		exit $return_var
   		;;
   	uninstall|uninst)
   		shift
   		echo $$ > /var/run/$PRODUCT_ID.pid
   		uninstall $1
   		[ -f /var/run/$PRODUCT_ID.pid ] && rm -f /var/run/$PRODUCT_ID.pid
   		;;
	*)
	 	disp_usage
		;;
esac