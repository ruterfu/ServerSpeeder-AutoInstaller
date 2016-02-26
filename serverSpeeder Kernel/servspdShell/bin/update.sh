#!/bin/echo Warning: this is a library file, can not be execute directly:
# Copyright (C) 2015 AppexNetworks
# Author:	Len
# Date:		Aug, 2015

getSysInfo() {
	# Get interface
	[ -f /proc/net/dev ] && {
		if grep 'eth0:' /proc/net/dev >/dev/null; then
			IFNAME=eth0
		else
			#exclude: lo sit stf gif dummy vmnet vir        
			IFNAME=`cat /proc/net/dev | awk -F: 'function trim(str){sub(/^[ \t]*/,"",str); sub(/[ \t]*$/,"",str); return str } NR>2 {print trim($1)}'  | grep -Ev '^lo|^sit|^stf|^gif|^dummy|^vmnet|^vir|^gre|^ipip|^ppp|^bond|^tun|^tap|^ip6gre|^ip6tnl|^teql' | awk 'NR==1 {print $0}' `
		fi
	}
	[ -z "$IFNAME" ] && {
	    echo "Network interface not found! (error code: 100)"
	    return 1
	}
	
	# Get kernel info
	KER_VER=`uname -r`
	SMP=`uname -a | grep SMP`
	X86_64=`uname -a | grep -i x86_64`
	
	[ -f /etc/os-release ] && {
		local NAME VERSION VERSION_ID PRETTY_NAME ID ANSI_COLOR CPE_NAME BUG_REPORT_URL HOME_URL ID_LIKE
		eval $(cat /etc/os-release) 2>/dev/null
		[ -n "$NAME" ] && DIST=$NAME
		[ -n "$VERSION_ID" ] && REL=$VERSION_ID
		[ -z "$REL" -a -n "$VERSION" ] && {
			for i in $VERSION; do
				ver=${i//./}
				if [ "$ver" -eq "$ver" 2> /dev/null ]; then
					REL=$i
					break
				fi
			done
		}
	}
	[ -z "$DIST" -o -z "$REL" ] && {
		[ -f /etc/redhat-release ] && line=$(cat /etc/redhat-release)
		[ -f /etc/SuSE-release ] && line=$(cat /etc/SuSE-release)
		[ -z "$line" ] && line=`cat /etc/issue`
		for i in $line; do
		    ver=${i//./}
		    if [ "$ver" -eq "$ver" 2> /dev/null ]; then
		        REL=$i
		        break
		    fi
		    [ "$i" = "release" -o "$i" = "Welcome" -o "$i" = "to" ] || DIST="$DIST $i"
		done
	}
	DIST=`echo $DIST | sed 's/^[ \s]*//g' | sed 's/[ \s]*$//g'`
	DIST=`echo $DIST | sed 's/[ ]/_/g'`
	MEM=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
}

function update() {
	echo
	echo "************************************************************"
	echo "*                                                          *"
	echo "*              ServerSpeeder Updater (1.2)                 *"        
	echo "*                                                          *"
	echo "************************************************************"
	echo
	
	# Locate wget
	which wget >/dev/null 2>&1
	[ $? -ne 0 ] && {
		echo 'ERROR(WGET): "wget" not found, please install "wget" using "yum install wget" or "apt-get install wget" according to your linux distribution'
		exit
	}
	
	KER_VER=''
	SMP=''
	X86_64=''
	DIST=""
	REL=""
	MEM=""
	IFNAME=eth0
	
	[ -z "$email" -o -z "$serial" ] && {
	    echo "Missing parmeters in config file: email or serial"
	    exit 1
	}
	getSysInfo
	acceVer=$(echo $apxexe | awk -F- '{print $2}')
	para="e=$email&s=$serial&l=$DIST&v=$REL&k=$KER_VER&i=$IFNAME&b=${X86_64:+1}&m=$MEM&accv=$acceVer&iv=$installerID"
	url="http://$HOST/ls_update.jsp?ml=$email&ml2=$serial"
	
	out=apxhttp.$$
	rm -rf $ROOT_PATH/update.tar.gz 2>/dev/null
	echo "Authenticating user..."
	wget --post-data $para -o $out -O $ROOT_PATH/update.tar.gz $url
	downStat=0
	[ -f $ROOT_PATH/update.tar.gz ] && {
	    filesize=0
	    stat=`which stat`
	    [ -n "$stat" ] && filesize=`stat -c "%s" $ROOT_PATH/update.tar.gz`
	    [ -z "$stat" ] && filesize=`ls -l $ROOT_PATH/update.tar.gz | awk '{print $5}'`
	    [ $filesize -gt 100 ] && downStat=1
	}
	if [ $downStat = 1 ]; then
	    sleep 1
	    dtstr=$(date +%Y-%m-%d_%H-%M-%S)
	    mkdir -p $ROOT_PATH/.bin_$dtstr $ROOT_PATH/.etc_$dtstr
	    mv -f $ROOT_PATH/bin/* $ROOT_PATH/.bin_$dtstr/
	    mv -f $ROOT_PATH/etc/* $ROOT_PATH/.etc_$dtstr/
	    
	    [ -d $ROOT_PATH/.tmp ] || mkdir -p $ROOT_PATH/.tmp
	    tar xzvf $ROOT_PATH/update.tar.gz -C $ROOT_PATH/.tmp 1>/dev/null 2>/dev/null
	    cp -f $ROOT_PATH/.tmp/bin/* $ROOT_PATH/bin/
	    cp -f $ROOT_PATH/.tmp/etc/* $ROOT_PATH/etc/
	    chmod +x $ROOT_PATH/bin/*
	    
	    [ -f $ROOT_PATH/.etc_$dtstr/clsf ] && cp -f $ROOT_PATH/.etc_$dtstr/clsf $ROOT_PATH/etc/
	    while read _line; do
			item=$(echo $_line | awk -F= '/^[^#]/ {print $1}')
			val=$(echo $_line | awk -F= '/^[^#]/ {print $2}' | sed 's#\/#\\\/#g')
			[ -n "$item" -a "$item" != "accpath" -a "$item" != "apxexe" -a "$item" != "apxlic" -a "$item" != "installerID" -a "$item" != "email" -a "$item" != "serial" ] && {
				if [ -n "$(grep $item $ROOT_PATH/etc/config)" ]; then
					sed -i "s/^#\{0,1\}$item=.*/$item=$val/" $ROOT_PATH/etc/config
				else
					sed -i "/^engineNum=.*/a$item=$val" $ROOT_PATH/etc/config
				fi
			}
		done<$ROOT_PATH/.etc_$dtstr/config
	    
	    [ -f $ROOT_PATH/.tmp/expiredDate ] && {
			echo -n "Expired Date: "
	    	cat $ROOT_PATH/.tmp/expiredDate
	    	echo
	  	}
	    rm -rf $ROOT_PATH/.tmp 2>/dev/null
	    [ "$1" != "-grace" ] && {
	    	echo -n "Restarting $PRODUCT_NAME..."
	    	. $ROOT_PATH/etc/config 2>/dev/null
	    	restart
		}
	    echo "Done!"
	else
	    grep 401 $out >/dev/null 2>&1 && {
	        echo "Invalid Email! (error code: 401)"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 403 $out >/dev/null 2>&1 && {
	        echo "$PRODUCT_NAME is up to date."
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 405 $out >/dev/null 2>&1 && {
	        echo "Your trial licenses have been used out! (error code: 405)"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 410 $out >/dev/null 2>&1 && {
			echo "License does not exist! (error code: 410)"
			rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
		}
	    grep 417 $out >/dev/null 2>&1 && {
	        echo "Your license has expired! (error code: 417)"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 501 $out >/dev/null 2>&1 && {
	        echo "No available versions found for your server! (error code: 501)"
	        echo "More information can be found from: http://$HOST/ls.do?m=availables"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 502 $out >/dev/null 2>&1 && {
	        echo "No available versions found for your server! (error code: 502)"
	        echo "More information can be found from: http://$HOST/ls.do?m=availables"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
	    grep 503 $out >/dev/null 2>&1 && {
	        echo "The license of this server is obsolete! (error code: 503)"
	        rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	        return 1
	    }
    	echo "Error occur! (error code: 400)"
    	cat $out
    	rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
	    return 1
	fi
	rm -rf $out $ROOT_PATH/update.tar.gz 2>/dev/null
}