#/bin/bash

## CREATE APPS CONFIG ROOT DIRECTORY
echo "checking apps config directory..."
check_apps_dir
function check_apps_dir (){

for i in 'openvpn' 'reverse_proxy' 'openldap' 'lamp'
do
  if [ -d "/srv/apps/$i" ];then
    echo"config directory for "$i"already exist"
  else
    echo "create "$i" config directory"
    mkdir -p /srv/apps/$i
  fi
done
main_menu
}

## ENSURE DOCKER AND DOCKER-COMPOSE IS INSTALLED

function docker_install (){

echo "installing docker dependencies"
apt install git curl apt-transport-https ca-certificates libffi-dev libssl-dev python3 python3-pip -y
apt-get remove python-configparser
echo "installing docker and docker-compose packages..."
echo "running download and install command --> curl -sSL https://get.docker.com | sh"
curl -sSL https://get.docker.com | sh 1&2>/dev/null
echo "running docker-compose installation with python-pip --> pip3 install docker-compose"
pip3 install docker-compose
echo "grant privileges on docker to current user --> usermod -aG docker $USER"
usermod -aG docker $USER

main_menu
}

## CONFIGURE REVERSE_PROXY

function reverse_proxy (){
read -e -i "$rootpasswd" -s -p "Set npm DB root password: " input
rootpasswd="${input:-$npmrootpasswd}"

read -e -i "$npmpasswd" -s -p "Set npm DB user password: " input
npmpasswd="${input:-$npmpasswd}"

cp ./reverse_proxy/config.json /srv/apps/reverse_proxy_app/config.json

sed -i "s/npm_psswd/$npmpasswd/g" config.json
sed -i "s/npmrootpass/$npmrootpasswd/g" docker-compose.yaml
sed -i "s/npmpass/$npmpasswd/g" docker-compose.yaml

docker-compose up -d reverse_proxy_db
docker-compose up -d reverse_proxy_app

main_menu
}

## CONFIGURE OPENVPN CONTAINER

function openvpn (){

ip=$(hostname -I | awk {print'$1'})
read -e -i "$vpnclientname" -s -p "vpn username : " input
vpnclientname="${input:-$vpnclientname}"

docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_genconfig -u tcp://$ip
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn ovpn_init pki
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn easyrsa build-client-full $clientname
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_getclient $clientname > $clientname.ovpn

main_menu
}

## DEPLOY CONTAINERS

#docker-compose up -d

function main_menu(){
trap "echo 'Control-C cannot been used now >:) ' ; sleep 1 ; clear ; continue " 1 2 3

while true
do
	clear
	echo "\t SECURE INFRASTRUCTURE INSTALLATION
	\t 1 -- \t 1
	\t 2 -- \t 2
	\t 3 -- \t 3
	\t Q -- \t QUIT (Leave this menu program)
	\t Type an option
	\t And type RETURN to back to main menu\c"

	read answer
	clear

	case "$answer" in
		[1]*) 1;;
		[2]*) 2;;
		[3]*) 3;;

		[Qq]*)  echo "See you soon..." ; exit 0 ;;
		*)      echo "Please choose an option..." ;;
	esac
	echo ""
	echo "type RETURN to back to main menu"
	read dummy
done
}
main_menu
