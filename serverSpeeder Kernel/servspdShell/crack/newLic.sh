#!bin/bash
# origin serverspeeder.com
# JUST FOR STUDY, if you like it please SUPPORT GENUINE
# Regenerate by Ruter
clear

echo "------------------------------------------------------------"
echo "  Regenerate Serverspeeder Ubuntu14.04|10 Installer by Ruter"
echo "  Update license key"
echo "  if you like, PLEASE SUPPORT GENUINE on http://www.serverspeeder.com/"
echo "------------------------------------------------------------"

echo "";

[ -w / ] || {
	echo "You are not running Installer as root, please rerun as root."
	echo "Installer now exit"
	echo ""
	exit 1
}

echo ""
echo -n "Press any key to continue..."
read nothing
NOWPATH=`dirname $0`
cd $NOWPATH
cd ../etc
HOST=`cat config | grep "host" | awk -F '=' '{print $2}'`
ROOT_PATH=`cat config | grep "rootpath" | awk -F '=' '{print $2}'`
NIC=`cat config | grep "accif" | awk -F '=' '{print $2}'`

NICLEN=`expr length $NIC`
let NICLEN=NICLEN-2
NIC=`expr substr $NIC 2 $NICLEN`

ROOTLEN=`expr length $ROOT_PATH`
let ROOTLEN=ROOTLEN-2
ROOT_PATH=`expr substr $ROOT_PATH 2 $ROOTLEN`

HOSTLEN=`expr length $HOST`
let HOSTLEN=HOSTLEN-2
HOST=`expr substr $HOST 2 $HOSTLEN`

echo "Getting Mac Address...."
MAC=`LANG=C ifconfig $NIC | awk '/HWaddr/{ print $5 }'`
echo "Your mac address is : $MAC"
echo "updating license from server..."
cd $ROOT_PATH/etc
rm apx.lic
wget -c -O "apx.lic" "$HOST/regenspeeder/lic?mac=$MAC&direct=1"
echo "Restarting Serverspeeder..."
bash $ROOT_PATH/bin/serverSpeeder.sh restart

