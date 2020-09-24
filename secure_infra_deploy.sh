#/bin/bash

## CREATE APPS CONFIG ROOT DIRECTORY
function check_apps_dir (){

for i in 'openvpn' 'reverse_proxy' 'openldap' 'lamp'
do
  if [ -d "/srv/apps/"$i ];then
    echo"config directory for "$i"already exist"
  else
    echo "create "$i" config directory"
    mkdir -p /srv/apps/$i
  fi
done
main_menu
}

## INSTALL DOCKER AND DOCKER-COMPOSE PACKAGE
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

## INSTALL REVERSE_PROXY NGINX-PROXY-MANAGER
function reverse_proxy (){
check_pkg docker

ip=$(hostname -I | awk {print'$1'})

read -e -i "$npmhttpp" -s -p "set npm http exposed port: " input
npmhttpp="${input:-$npmhttpp}"

read -e -i "$npmhttpsp" -s -p "set npm https exposed port: " input
npmhttpsp="${input:-$npmhttpsp}"

read -e -i "$npmadminp" -s -p "set npm admin exposed port: " input
npmadminp="${input:-$npmadminp}"

read -e -i "$rootpasswd" -s -p "Set npm DB root password: " input
rootpasswd="${input:-$npmrootpasswd}"

read -e -i "$npmpasswd" -s -p "Set npm DB user password: " input
npmpasswd="${input:-$npmpasswd}"

sed -i "s/npm_psswd/$npmpasswd/g" ./reverse_proxy/config.json
cp ./reverse_proxy/config.json /srv/apps/reverse_proxy_app/config.json

sed -i "s/npm_http_port/$npmhttpp/g" docker-compose.yaml
sed -i "s/npm_https_port/$npmhttpsp/g" docker-compose.yaml
sed -i "s/npm_admin_port/$npmadminp/g" docker-compose.yaml
sed -i "s/npmrootpass/$npmrootpasswd/g" docker-compose.yaml
sed -i "s/npmpass/$npmpasswd/g" docker-compose.yaml

docker-compose up -d reverse_proxy_db
docker-compose up -d reverse_proxy_app

echo "Your admin interface is deployed on http://"$ip":"$npmadminp
echo "default login are : admin@example.com / changeme"

main_menu
}

## INSTALL OPENVPN SERVER
function openvpn (){
check_pkg docker
ip=$(hostname -I | awk {print'$1'})
read -e -i "$vpnclientname" -s -p "vpn username : " input
vpnclientname="${input:-$vpnclientname}"
read -e -i "$openvpnp" -s -p "set openvpn exposed port: " input
openvpnp="${input:-$openvpnp}"

sed -i "s/openvpn_port/$openvpnp/g" docker-compose.yaml

docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_genconfig -u tcp://$ip
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn ovpn_init pki
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn easyrsa build-client-full $clientname
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_getclient $clientname > $clientname.ovpn

docker-compose up -d openvpn

main_menu
}

## CONFIGURE PORT KNOCKING WITH LAMP INFRASTRCUTURE
function pknocking(){
echo "wip"
pause
main_menu
}

## INSTALL LAMP INFRASTRUCTURE
function lamp(){
echo "wip"
pause
main_menu
}

## INSTALL LDAP RADIUS SERVER
function ldap_radius(){
echo "wip"
pause
main_menu
}


## CHECK IF INPUT PACKAGE IS INSTALLED
function check_pkg(){
check=$(dpkg -l | grep $1 | tail -n1 | awk {print'$1'})
if [[ $check = "ii" ]]; then
  echo $1 "package already installed"
else
  echo $1 "package doesn't installed, please install this one first"
  pause
  main_menu
fi
}

function pause(){
 read -s -n 1 -p "Press any key to continue..."
 echo ""
}


## MAIN MENU
function main_menu(){
trap "echo 'Control-C cannot been used now >:) ' ; sleep 1 ; clear ; continue " 1 2 3
while true
do
  clear
  echo "
---------- SECURE INFRASTRUCTURE INSTALLATION ----------
1 --> Install Docker (required)
2 --> Install Reverse Proxy
3 --> Install OpenVPN Server
4 --> Configure PortKnocking (LAMP required)
5 --> Install LAMP (with NGINX instead Apache)
6 --> Install OpenLDAP/Radius
Q --> QUIT (Leave this menu program)

Type an option
And type RETURN to back to main menu\c"

  read answer
  clear

  case "$answer" in
    [1]*) docker_install;;
    [2]*) reverse_proxy;;
    [3]*) openvpn;;
    [4]*) pknocking;;
    [5]*) lamp;;
    [6]*) ldap_radius;;
    [Qq]*)  echo "See you soon..." ; exit 0 ;;
  *)      echo "Please choose an option..." ;;
  esac
  echo ""
  echo "type RETURN to back to main menu"
  read dummy
done
}
echo "checking apps config directory..."
check_apps_dir
main_menu
