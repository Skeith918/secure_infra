#/bin/bash

## CREATE APPS CONFIG ROOT DIRECTORY
function check_apps_dir (){
  for i in 'openvpn' 'reverse_proxy' 'openldap' 'lamp'
  do
    if [ -d "/srv/apps/"$i ];then
      echo "config directory for "$i"already exist"
    else
      echo "create "$i" config directory"
      mkdir -p /srv/apps/$i
    fi
  done
}

## CHECK IF CONTAINER CONFIG FILE ALREADY EXIST
function check_config_file (){
  if [ -f "./docker-compose.yaml" ];then
    while true
    do
      read -r -p "Container config file already, overwritten ? [Y/n/cancel]" input
        case $input in [yY][eE][sS]|[yY])
          rm -f ./docker-compose.yaml
          cp ./docker-compose.yaml.original ./docker-compose.yaml
        break
        ;;
	[nN][oO]|[nN])
	;;
        [cancel])
        break
        ;;
        *)
        echo "Please answer yes or no or cancel.."
        ;;
        esac
    done
  else
    echo "config file doesn't exist, copy original file..."
    cp ./docker-compose.yaml.original ./docker-compose.yaml
    pause
  fi
}

## INSTALL DOCKER AND DOCKER-COMPOSE PACKAGE
function docker_install () {
  echo "installing docker dependencies"
  apt install git curl apt-transport-https ca-certificates libffi-dev libssl-dev python3 python3-pip -y -q
  apt-get remove python-configparser -q

  echo "installing docker and docker-compose packages..."
  echo "running download and install command --> curl -sSL https://get.docker.com | sh"
  curl -sSL https://get.docker.com | sh

  echo "running docker-compose installation with python-pip --> pip3 install docker-compose"
  pip3 install docker-compose

  echo "grant privileges on docker to current user --> usermod -aG docker $USER"
  usermod -aG docker $USER
}

## INSTALL REVERSE_PROXY NGINX-PROXY-MANAGER
function reverse_proxy (){
  ### CHECK IF DOCKER IS INSTALLED
  check_pkg docker
  ### RETRIEVE ALL INPUT VAR FOR PORTS AND PASS CONFIGURATION
  read -r -p "set npm http exposed port: " npmhttpp
  read -r -p "set npm https exposed port: " npmhttpsp
  read -r -p "set npm admin exposed port: " npmadminp
  read -s -r -p "Set npm DB root password: " npmrootpasswd
  read -s -r -p "Set npm DB user password: " npmpasswd

  ### SET PASS AND PORTS ON CONFIG FILE
  sed -i "s/npm_psswd/$npmpasswd/g" ./reverse_proxy/config.json
  cp ./reverse_proxy/config.json /srv/apps/reverse_proxy/config.json
  sed -i "s/npm_http_port/$npmhttpp/g" docker-compose.yaml
  sed -i "s/npm_https_port/$npmhttpsp/g" docker-compose.yaml
  sed -i "s/npm_admin_port/$npmadminp/g" docker-compose.yaml
  sed -i "s/npmrootpass/$npmrootpasswd/g" docker-compose.yaml
  sed -i "s/npmpass/$npmpasswd/g" docker-compose.yaml

  ### CREATE CONTAINER
  docker-compose up -d reverse_proxy_db
  docker-compose up -d reverse_proxy_app

  ### SUCCESS MESSAGE AND DEFAULT CONFIGURATION
  ip=$(hostname -I | awk {print'$1'})
  echo "Your admin interface is deployed on http://"$ip":"$npmadminp
  echo "default login are : admin@example.com / changeme"
}

## INSTALL OPENVPN SERVER
function openvpn (){
  ### CHECK IF DOCKER IS INSTALLED
  check_pkg docker

  ### RETRIEVE ALL INPUT VAR FOR PORTS AND PASS CONFIGURATION
  ip=$(hostname -I | awk {print'$1'})
  read -r "$vpnclientname" -p "vpn username : " input
  vpnclientname="${input:-$vpnclientname}"
  read -r "$openvpnp" -p "set openvpn exposed port: " input
  openvpnp="${input:-$openvpnp}"

  ### SET PORT ON CONFIG FILE
  sed -i "s/openvpn_port/$openvpnp/g" docker-compose.yaml

  ### CONFIGURE SERVER AND GENERATE CLIENT FILE
  docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_genconfig -u tcp://$ip
  docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn ovpn_init pki
  docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn easyrsa build-client-full $clientname
  docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_getclient $clientname > $clientname.ovpn

  ### CREATE CONTAINER
  docker-compose up -d openvpn
}

## CONFIGURE PORT KNOCKING WITH LAMP INFRASTRCUTURE
function pknocking(){
  check_pkg docker
  check_lamp=$(docker ps -a | grep nginx | awk pring{print'$6'})
  if [[ $check = "lamp_nginx" ]]; then
    echo "OK"
  else
    echo "lamp infrastrcuture doesn't exist; please create this one first"
  fi
}

## INSTALL LAMP INFRASTRUCTURE
function lamp(){
  read -r "$nginxp" -p "set nginx exposed port: " input
  nginxp="${input:-$nginxp}"

  docker-compose up -d lamp_nginx
  docker-compose up -d lamp_mariadb
  docker-compose up -d lamp_phpmyadmin
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
fi
}

## PAUSE FUNCTION
function pause(){
  read -s -n 1 -p "Press any key to continue..."
  echo ""
}

## MAIN MENU
function xmenu(){
  ### DISABLE CTRL-C FEATURE
  trap "echo 'Control-C cannot been used now >:) ' ; sleep 1 ; clear ; continue " 1 2 3
  INPUT=/tmp/menu.sh.$$

  while true
  do
    dialog --clear  --help-button --backtitle "Docker Secure Infrastructure" \
    --title "[ M A I N - M E N U ]" \
    --menu "You can use the UP/DOWN arrow keys, the first \n\
    letter of the choice as a hot key, or the \n\
    number keys 1-9 to choose an option.\n\
    Choose the TASK" 15 50 4 \
    1 "Install Docker 'required" \
    2 "Install Reverse_Proxy" \
    3 "Install OpenVPN Server" \
    Exit "Exit to the shell" 2>"${INPUT}"

    menuitem=$(<"${INPUT}")

    case $menuitem in
	1) docker_install;;
	2) reverse_proxy;;
	3) openvpn;;
	Exit) clear;echo "Bye"; break;;
    esac
  done
  [ -f $INPUT ] && rm $INPUT
}
check_apps_dir
check_config_file
check_pkg dialog
xmenu

