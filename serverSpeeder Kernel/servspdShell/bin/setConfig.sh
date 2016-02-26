#!/bin/bash
# Copyright (C) 2015 AppexNetworks
# Author:	Len
# Date:		Aug, 2015

ROOT_PATH=/serverspeeder
PRODUCT_NAME=ServerSpeeder

[ -f $ROOT_PATH/etc/config ] || { echo "Missing file: $ROOT_PATH/etc/config"; exit 1; }
. $ROOT_PATH/etc/config 2>/dev/null
KILLNAME=$(echo $(basename $apxexe) | sed "s/-\[.*\]//")
[ -z "$KILLNAME" ] && KILLNAME="acce-";
pkill -0 $KILLNAME 2>/dev/null
[ $? -eq 0 ] || {
    echo "$PRODUCT_NAME is NOT running!"
    exit 1
}

help() {
	echo "Usage: $0 <config> <value1> [value2 ... [valueN]]"
	echo ""
	echo "e.g. $0 wanIf eth0"
}

item=$1
shift
value=$@

[[ -z "$item" || -z "$value" || "$item" = "-help" || "$item" = "--help" ]] && {
	help
	exit 1
}
if [ $usermode -eq 0 ]; then
	[ -f /proc/net/appex/$item ] || grep "$item:" /proc/net/appex/cmd >/dev/null || [ $item = "pcapFilterSplit" ] || {
		echo "Invalid config! "
		exit 1
	}
	
	for engine in $(ls -d /proc/net/appex*); do
		if [ -f $engine/$item ]; then
			echo "$value" > $engine/$item 2>/dev/null
			if [ $item = 'wanIf' ]; then
				saved=$(cat $engine/$item 2>/dev/null)
				saved=$(echo $saved)
		    	for if in $value; do
		    		[ "${saved/$if}" == "$saved" ] && {
		    			echo "Failed to write configuration!"
				    	exit 1
		    		}
		    	done
			else
				saved=$(cat $engine/$item 2>/dev/null)
				saved=$(echo $saved)
				[ "$value" != "$saved" ] && {
					echo "Failed to write configuration!"
					exit 1
				}
			fi
		else
			echo "$item: $value" > $engine/cmd 2>/dev/null
			saved=$(awk -F': ' "/$item(\(.*\))?:/ {print \$2}" $engine/cmd 2>/dev/null)
			if [ $item = 'lanSegment' ]; then
				[[ ${saved#$value} == $saved && ${value#$saved} == $value ]] && {
					echo "Failed to write configuration: lansegment"
					exit 1
				}
			else
				[ "$value" != "$saved" ] && {
					echo "Failed to write configuration!"
					exit 1
				}
			fi
		fi
	done
else
	for i in $($apxexe | sed 's/\[.*\]//g'); do
		[[ "$i" != "$item" ]] && continue
		$apxexe /0/$item="$value"
		saved=$($apxexe /0/$item)
		saved=$(echo $saved)
		if [ $item = 'wanIf' ]; then
	    	for if in $value; do
	    		[ "${saved/$if}" == "$saved" ] && {
	    			echo "Failed to write configuration!"
			    	exit 1
	    		}
	    	done
		else
			[ "$value" != "$saved" ] && {
				echo "Failed to write configuration!"
				exit 1
			}
		fi
		exit 0
	done
	
	for i in $($apxexe /0/cmd | awk -F: '{print $1}') pcapFilterSplit; do
		[[ "$i" != "$item" ]] && continue
		$apxexe /0/cmd="$item $value"
		saved=$($apxexe /0/cmd | awk -F': ' "/$item(\(.*\))?:/ {print \$2}")
		if [ $item = 'lanSegment' ]; then
			[[ ${saved#$value} == $saved && ${value#$saved} == $value ]] && {
				echo "Failed to write configuration: lansegment"
				exit 1
			}
		else
			[ "$value" != "$saved" ] && {
				echo "Failed to write configuration!"
				exit 1
			}
		fi
		exit 0
	done
	echo "Invalid config! "
	exit 1
	
fi