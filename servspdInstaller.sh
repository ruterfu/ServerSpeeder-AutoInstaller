#!bin/bash
# origin serverspeeder.com
# JUST FOR STUDY, if you like it please SUPPORT GENUINE
# Regenerate by Ruter

#YOUR SERVER HOST change this
HOST=http://ip.com[:port]
#YOUR SERVER HOST ADDRESS it will write to /etc/hosts
HOSTADDR=[hostIP]


ROOT_PATH=/serverspeeder
NIC=eth0
KERNELNAME="";
clear
echo "------------------------------------------------------------"
echo "  Regenerate Serverspeeder Ubuntu14.04|10 Installer by Ruter"
echo "  This installer just for study"
echo "------------------------------------------------------------"

echo "";

[ -w / ] || {
	echo "You are not running Installer as root, please rerun as root."
	echo "Installer now exit"
	echo ""
	exit 1
}


echo -n "Enter your accelerated interface(s) [eth0]: "
read hwinter;
if [ -n "$hwinter" ]; then
	NIC=$hwinter
fi
outbound="1000000"
inbound="1000000"

echo ""
echo "Getting Mac Address...."
MAC=`LANG=C ifconfig $NIC | awk '/HWaddr/{ print $5 }'`
if [ ! -n "$MAC" ]; then
	echo "$NIC not found!"
	echo "Installer now exit"
	exit 1
fi
echo "Your mac address is : $MAC"
echo "Creating serverspeeder directory..."
if [ -d "$ROOT_PATH" ]; then
	rm -r $ROOT_PATH
fi
mkdir -p $ROOT_PATH/bin
mkdir -p $ROOT_PATH/etc
mkdir -p $ROOT_PATH/log
mkdir -p $ROOT_PATH/tmp
mkdir -p $ROOT_PATH/crack

cd $ROOT_PATH/tmp
echo "Checking kernel..."
KERNALVER=`uname -r`
SYSVER=`getconf LONG_BIT`
wget -c -q -O kernelShell.sh "$HOST/regenspeeder/kernelsearch?kernel=$KERNALVER&ver=$SYSVER"

chmod -x kernelShell.sh
source kernelShell.sh

cd $ROOT_PATH/etc

echo "Downloading license from server..."
wget -c -q -O "apx.lic" "$HOST/regenspeeder/lic?mac=$MAC"

echo "Runnable file now downloading..."
cd $ROOT_PATH/tmp
echo  "Downloading file serverSpeeder Shell..."
wget -c -q "$HOST/serverspeeder/servspdShell.tar.gz"

echo "Download finished!"

echo "Unpacking files..."
tar zxf ./servspdShell.tar.gz
echo "Copying files..."
cp bin/* ../bin/
cp etc/* ../etc/
cp crack/* ../crack/

echo "Dumping configuration..."
cd $ROOT_PATH/etc
echo accif=\"$NIC\" >> $ROOT_PATH/etc/config
echo wankbps=\"$outbound\" >> $ROOT_PATH/etc/config
echo waninkbps=\"$inbound\" >> $ROOT_PATH/etc/config
echo apxexe=\"$ROOT_PATH/bin/$KERNELNAME\" >> $ROOT_PATH/etc/config
echo macaddr=\"$MAC\" >> $ROOT_PATH/etc/config
echo host=\"$HOST\" >> $ROOT_PATH/etc/config
echo rootpath=\"$ROOT_PATH\" >> $ROOT_PATH/etc/config

echo "Dump configuration succeeded!"
echo "Attemping hosts redirect..."
HOSTS=`cat /etc/hosts | grep 'dl.serverspeeder.com' | awk '{print $1}'`
if [ "$HOSTS" != $HOSTADDR ]; then
	echo "$HOSTADDR dl.serverspeeder.com" >> /etc/hosts
fi

HOSTS=`cat /etc/hosts | grep 'www.serverspeeder.com' | awk '{print $1}'`
if [ "$HOSTS" != "127.0.0.1" ]; then
	echo "127.0.0.1 www.serverspeeder.com" >> /etc/hosts
fi

HOSTS=`cat /etc/hosts | grep 'my.serverspeeder.com' | awk '{print $1}'`
if [ "$HOSTS" != "127.0.0.1" ]; then
	echo "127.0.0.1 my.serverspeeder.com" >> /etc/hosts
fi

echo "Removing all temporary files..."
rm -r $ROOT_PATH/tmp


chmod +x $ROOT_PATH/bin/*
chmod +x $ROOT_PATH/crack/

echo "Starting Serverspeeder ..."
bash $ROOT_PATH/bin/serverSpeeder.sh start
echo "Have Fun!"
exit 0
