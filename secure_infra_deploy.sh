#/bin/bash

apt install dialog jq -y

## CREATE APPS CONFIG ROOT DIRECTORY

function read_param (){
  port=$(jq -r '.'$1'.'$2'' ./config/config.json)
  echo $port
}

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
      read -r -p "Container config file already, overwritten ? [Yes/No]" input
        case $input in [yY][eE][sS]|[yY])
          rm -f ./docker-compose.yaml
          cp ./docker-compose.yaml.original ./docker-compose.yaml
        break
        ;;
	[nN][oO]|[nN])
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

function set_config (){

  ### RETRIEVE ALL VAR VALUES FOR PORTS AND PASS CONFIGURATION

  rp_http=$(read_param reverse_proxy http_port)
  rp_https=$(read_param reverse_proxy https_port)
  rp_admin=$(read_param reverse_proxy admin_port)
  rp_dbrootpass=$(read_param reverse_proxy dbrootpass)
  rp_dbadminpass=$(read_param reverse_proxy dbadminpass)
  openvpn_ip=$(read_param openvpn server_ip)
  openvpn_port=$(read_param openvpn ovpn_port)
  openvpn_username=$(read_param openvpn client_username)

  sed -i "s/npm_http_port/$rp_http/g" docker-compose.yaml
  sed -i "s/npm_https_port/$rp_https/g" docker-compose.yaml
  sed -i "s/npm_admin_port/$rp_admin/g" docker-compose.yaml
  sed -i "s/npmrootpass/$rp_dbrootpass/g" docker-compose.yaml
  sed -i "s/npmpass/$rp_dbadminpass/g" docker-compose.yaml
  sed -i "s/openvpn_port/$openvpn_port/g" docker-compose.yaml

}

## CHECK IF INPUT PACKAGE IS INSTALLED
function check_pkg(){
  check=$(dpkg -l | grep $1 | tail -n1 | awk {print'$1'})
  if [[ $check = "ii" ]]; then
    echo $1 "package is already installed"
  else
    while true
    do
      read -r -p $1 "package isn't installed and is needed, do you want install it ? [Yes/No]" input
        case $input in [yY][eE][sS]|[yY])
          apt install $1 -y
        break
        ;;
        [nN][oO]|[nN])
        break
        ;;
        *)
        echo "Please answer yes or no or cancel.."
        ;;
        esac
    done
    pause
fi
}

## PAUSE FUNCTION
function pause(){
  read -s -n 1 -p "Press any key to continue..."
  echo ""
}

## INSTALL DOCKER AND DOCKER-COMPOSE PACKAGE
function docker_install () {
  clear
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
  clear
  ### CHECK IF DOCKER IS INSTALLED
  check_pkg docker

   ## SET PASS AND PORTS ON CONFIG FILE
  cp ./reverse_proxy/config.json /srv/apps/reverse_proxy/config.json
  sed -i "s/npm_psswd/$rp_adminpass/g" /srv/apps/reverse_proxy/config.json

  ## CREATE CONTAINER
  docker-compose up -d reverse_proxy_db
  docker-compose up -d reverse_proxy_app

  ### SUCCESS MESSAGE AND DEFAULT CONFIGURATION
  ip=$(hostname -I | awk {print'$1'})
  echo "Your admin interface is deployed on http://"$ip":"$rp_admin
  echo "default login are : admin@example.com / changeme"
  pause
}

## INSTALL OPENVPN SERVER
function openvpn (){
  ### CHECK IF DOCKER IS INSTALLED
  check_pkg docker
  clear

  ip=$(hostname -I | awk {print'$1'})
  ### CONFIGURE SERVER AND GENERATE CLIENT FILE
  docker-compose run --rm openvpn ovpn_genconfig -u tcp://$openvpn_ip:$openvpn_port -e 'port-share '$ip' '$rp_http''
  touch /srv/apps/openvpn/data/vars
  pause
  docker-compose run --rm openvpn ovpn_initpki
  pause
  chown -R $USER: /srv/apps/openvpn
  docker-compose up -d openvpn
  pause
  docker-compose run --rm openvpn easyrsa build-client-full $openvpn_username
  pause
  docker-compose run --rm openvpn ovpn_getclient $openvpn_username > $openvpn_username.ovpn
  pause
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

## MAIN MENU
function main_menu(){
  INPUT=/tmp/menu.sh.$$

  while true
  do
    dialog --clear  --help-button --backtitle "Docker Secure Infrastructure" \
    --title "[ M A I N - M E N U ]" \
    --menu "You can use the UP/DOWN arrow keys,or the \n\
number keys 1-9 to choose an option.\n\
Choose the TASK" 15 50 4 \
    1 "Install Docker (required)" \
    2 "Install Reverse_Proxy" \
    3 "Install OpenVPN Server" \
    4 "Install Port Knocking Architecture" \
    5 "Install LNMP Architecture" \
    Exit "Exit to the shell" 2>"${INPUT}"

    menuitem=$(<"${INPUT}")

    case $menuitem in
	1) docker_install;;
	2) reverse_proxy;;
	3) openvpn;;
        4) port_knocking;;
        5) lnmp;;
	Exit) clear;echo "Bye"; break;;
    esac
  done
  [ -f $INPUT ] && rm $INPUT
}
check_apps_dir
check_config_file
set_config
main_menu
