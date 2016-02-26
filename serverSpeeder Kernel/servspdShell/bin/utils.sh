#!/bin/bash
# Copyright (C) 2015 AppexNetworks
# Author:	Len
# Date:		Aug, 2015
#

ROOT_PATH=/serverspeeder
PRODUCT_NAME=ServerSpeeder

[ -f $ROOT_PATH/etc/config ] || { echo "Missing file: $ROOT_PATH/etc/config"; exit 1; }
. $ROOT_PATH/etc/config 2>/dev/null

# Locate bc
BC=`which bc`
[ -z "$BC" ] && {
    echo "bc not found, please install \"bc\" using \"yum install bc\" or \"apt-get install bc\" according to your linux distribution"
    exit 1
}

KILLNAME=$(echo $(basename $apxexe) | sed "s/-\[.*\]//")
[ -z "$KILLNAME" ] && KILLNAME="acce-";
pkill -0 $KILLNAME 2>/dev/null
[ $? -eq 0 ] || {
    echo "$PRODUCT_NAME is NOT running!"
    exit 1
}

CPUNUM=0
VER_STAGE=1
TOTAL_TIME=65535
CALC_ITV=5 #seconds
HL_START="\033[37;40;1m"
HL_END="\033[0m" 
[ -z "$usermode" ] && usermode=0

ip2long() {
  local IFS='.'
  read ip1 ip2 ip3 ip4 <<<"$1"
  echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4))
  #echo "$ip1 $ip2 $ip3 $ip4"
}

getVerStage() {
	verName=$(echo $apxexe | awk -F- '{print $2}')
	intVerName=$(ip2long $verName)
	
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

getCpuNum() {
	[ $usermode -eq 1 ] && {
		CPUNUM=1
		return
	}
	[ $VER_STAGE -eq 1 ] && {
		CPUNUM=1
		return
	}
	if [ $VER_STAGE -ge 4 -a -n "$cpuID" ]; then
		CPUNUM=$(echo $cpuID | awk -F, '{print NF}')
		#num=`cat /proc/stat | grep cpu | wc -l`
		#num=`expr $num - 1`
		#[ $CPUNUM -gt $num ] && echo
	else
		num=`cat /proc/stat | grep cpu | wc -l`
		num=`expr $num - 1`
		CPUNUM=$num
		[ -n "$engineNum" ] && {
			[ $engineNum -gt 0 -a $engineNum -lt $num ] && CPUNUM=$engineNum
		}
		X86_64=$(uname -a | grep -i x86_64)
		[ -z "$X86_64" -a $CPUNUM -gt 4 ] && CPUNUM=4
	fi
	[ -n "$1" -a -n "$X86_64" -a $CPUNUM -gt 4 ] && {
		memTotal=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
		used=$(($CPUNUM * 800000)) #800M
		left=$(($memTotal - $used))
		[ $left -lt 2000000 ] && {
			HL_START="\033[37;40;1m"
			HL_END="\033[0m"
			echo -en "$HL_START"
			echo "$PRODUCT_NAME Warning: $CPUNUM engines will be launched according to the config file. Your system's total RAM is $memTotal(KB), which might be insufficient to run all the engines without performance penalty under extreme network conditions. "
			echo -en "$HL_END"
		}    
	}
}

initCmd() {
    eNum=0
    while [ $eNum -lt $CPUNUM ]; do
        if [ $usermode -eq 0 ]; then
        	e=$eNum
        	[ $e -eq 0 ] && e=''
	        [ -d /proc/net/appex$e ] && {
	            echo "displayLevel: 5" > /proc/net/appex$e/cmd
	        }
        else
        	$apxexe /$eNum/cmd="displayLevel 5"
        fi
        ((eNum = $eNum + 1))
    done
}

showStats() {
    initCmd
    count=0
    lstTime=$(date +%s)
    cmd=''
    showLan=''
    [ "$1" = "all" ] && showLan=1
    while [ $count -lt $TOTAL_TIME ]; do
        eNum=0
        cmd=''
        wanInRateTotal=0
        lanInRateTotal=0
        wanOutRateTotal=0
        lanOutRateTotal=0
        NumOfFlowsTotal=0
        NumOfTcpFlowsTotal=0
        NumOfAccFlowsTotal=0
        NumOfActFlowsTotal=0
        NfBypassTotal=0
        lanInValTotal=0
        wanOutValTotal=0
        while [ $eNum -lt $CPUNUM ]; do
        	if [ $usermode -eq 0 ]; then
        		e=$eNum
	            [ $e -eq 0 ] && e=''
	            [ -d /proc/net/appex$e ] || {
	                ((eNum = $eNum + 1))
	                continue
	            }
	            eval $(cat /proc/net/appex$e/stats | egrep '(NumOf.*Flows)|(Bytes)|(NfBypass)' | sed 's/\s*//g')
        	else
        		eval $($apxexe /$eNum/stats | egrep '(NumOf.*Flows)|(Bytes)|(NfBypass)' | sed 's/\s*//g')
        	fi
	            
            [ -z "$NumOfFlows" ] && NumOfFlows=0
            [ -z "$NumOfTcpFlows" ] && NumOfTcpFlows=0
            [ -z "$NumOfAccFlows" ] && NumOfAccFlows=0
            [ -z "$NumOfActFlows" ] && NumOfActFlows=0
            [ -z "$WanInBytes" ] && WanInBytes=0
            [ -z "$LanInBytes" ] && LanInBytes=0
            [ -z "$WanOutBytes" ] && WanOutBytes=0
            [ -z "$LanOutBytes" ] && LanOutBytes=0
            [ -z "$NfBypass" ] && NfBypass=0
            
            eval wanInPre=\$wan_in_pre_$e
            eval lanInPre=\$lan_in_pre_$e
            eval wanOutPre=\$wan_out_pre_$e
            eval lanOutPre=\$lan_out_pre_$e
            
            wanIn=$WanInBytes
            lanIn=$LanInBytes
            wanOut=$WanOutBytes
            lanOut=$LanOutBytes
            
            [ -z "$wanInPre" ] && {
                wanInPre=$wanIn
                lanInPre=$lanIn
                wanOutPre=$wanOut
                lanOutPre=$lanOut
            }
            
            eval wan_in_pre_$e=$wanIn
            eval lan_in_pre_$e=$lanIn
            eval wan_out_pre_$e=$wanOut
            eval lan_out_pre_$e=$lanOut

            wanInVal=$(echo "$wanIn - $wanInPre" | bc -l)
            lanInVal=$(echo "$lanIn - $lanInPre" | bc -l)
            wanOutVal=$(echo "$wanOut - $wanOutPre" | bc -l)
            lanOutVal=$(echo "$lanOut - $lanOutPre" | bc -l)
                                    
            #calc ratio
            wanInRate=$(echo "$wanInVal / (128 * $CALC_ITV)" | bc -l)
            lanInRate=$(echo "$lanInVal / (128 * $CALC_ITV)" | bc -l)
            wanOutRate=$(echo "$wanOutVal / (128 * $CALC_ITV)" | bc -l)
            lanOutRate=$(echo "$lanOutVal / (128 * $CALC_ITV)" | bc -l)
            
            # ratio of lanin wanout #(wanout - lanin) / wanout
			if [ $wanOutVal -gt 0 ]; then
				outRatio=$(echo "($wanOutVal - $lanInVal) * 100 / $wanOutVal" | bc -l)
			else
				outRatio=0
			fi
            
            if [ $CPUNUM -gt 1 ]; then
                ((NumOfFlowsTotal = $NumOfFlowsTotal + $NumOfFlows))
                ((NumOfTcpFlowsTotal = $NumOfTcpFlowsTotal + $NumOfTcpFlows))
                ((NumOfAccFlowsTotal = $NumOfAccFlowsTotal + $NumOfAccFlows))
                ((NumOfActFlowsTotal = $NumOfActFlowsTotal + $NumOfActFlows))
                wanInRateTotal=$(echo "$wanInRateTotal + $wanInRate" | bc -l)
                lanInRateTotal=$(echo "$lanInRateTotal + $lanInRate" | bc -l)
                wanOutRateTotal=$(echo "$wanOutRateTotal + $wanOutRate" | bc -l)
                lanOutRateTotal=$(echo "$lanOutRateTotal + $lanOutRate" | bc -l)
                ((NfBypassTotal = $NfBypassTotal + $NfBypass))
                ((wanOutValTotal = $wanOutValTotal + $wanOutVal))
                ((lanInValTotal = $lanInValTotal + $lanInVal))
            fi
            
            cmd="$cmd echo \"engine#$eNum:\";"
            cmd="$cmd printf \"sessions: $HL_START%d$HL_END, \" $NumOfFlows;"
            cmd="$cmd printf \"tcp sessions: $HL_START%d$HL_END, \" $NumOfTcpFlows;"
            cmd="$cmd printf \"accelerated tcp sessions: $HL_START%d$HL_END, \" $NumOfAccFlows;"
            cmd="$cmd printf \"active tcp sessions: $HL_START%d$HL_END, \" $NumOfActFlows;"
            [ $NfBypass -gt 0 ] && cmd="$cmd printf \"Short-RTT bypassed packets: $HL_START%d$HL_END\n\" $NfBypass;"
            #echo
            cmd="$cmd printf \"\${showLan:+wan }in :  $HL_START%.2F$HL_END kbit/s\t\${showLan:+wan }out: $HL_START%.2F$HL_END kbit/s\n\" $wanInRate $wanOutRate;"
            [ -n "$showLan" ] && {
            	cmd="$cmd printf \"lan out: $HL_START%.2F$HL_END kbit/s\tlan in :  $HL_START%.2F$HL_END kbit/s\n\" $lanOutRate $lanInRate;"
            	cmd="$cmd printf \"retransmission ratio: $HL_START%.1F %%$HL_END \" $outRatio;"
            }
            cmd="$cmd printf \"\n\";"
            ((eNum = $eNum + 1))
            ((NfBypass = 0))
        done
        if [ $CPUNUM -gt 1 ]; then
            cmd="$cmd echo \"Total:\";"
            cmd="$cmd printf \"sessions: $HL_START%d$HL_END, \" $NumOfFlowsTotal;"
            cmd="$cmd printf \"tcp sessions: $HL_START%d$HL_END, \" $NumOfTcpFlowsTotal;"
            cmd="$cmd printf \"accelerated tcp sessions: $HL_START%d$HL_END, \" $NumOfAccFlowsTotal;"
            cmd="$cmd printf \"active tcp sessions: $HL_START%d$HL_END, \" $NumOfActFlowsTotal;"
            cmd="$cmd printf \"Short-RTT bypassed packets: $HL_START%d$HL_END\n\" $NfBypassTotal;"
            #echo
            cmd="$cmd printf \"\${showLan:+wan }in :  $HL_START%.2F$HL_END kbit/s\t\${showLan:+wan }out: $HL_START%.2F$HL_END kbit/s\n\" $wanInRateTotal $wanOutRateTotal;"
            [ -n "$showLan" ] && {
            	cmd="$cmd printf \"lan out: $HL_START%.2F$HL_END kbit/s\tlan in :  $HL_START%.2F$HL_END kbit/s\n\" $lanOutRateTotal $lanInRateTotal;"
            	
            	if [ $wanOutValTotal -gt 0 ]; then
            		outRatio=$(echo "($wanOutValTotal - $lanInValTotal) * 100 / $wanOutValTotal" | bc -l)
            	else
            		outRatio=0
            	fi
            	cmd="$cmd printf \"retransmission ratio: $HL_START%.1F %%$HL_END \" $outRatio;"
            }
            echo
        fi
        clear
        eval $cmd
        sleep $CALC_ITV
        ((count = $count + $CALC_ITV))
    done
}

getVerStage
[ $VER_STAGE -eq 1 ] && {
	echo 'Not available for this version!'
	exit 1
}
getCpuNum
showStats $1
