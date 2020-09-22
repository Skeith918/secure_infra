#/bin/bash

## CREATE APPS CONFIG ROOT DIRECTORY

for i in 'openvpn' 'reverse_proxy' 'openldap' 'lamp'
do
  if [ -d "/srv/apps/$i" ];then
    echo"root dir for "$i"already exist"
  else
    mkdir -p /srv/apps/$i
  fi
done

## ENSURE DOCKER AND DOCKER-COMPOSE IS INSTALLED

curl -sSL https://get.docker.com | sh
pip3 install docker-compose
usermod -aG docker $USER

## CONFIGURE OPENVPN CONTAINER

ip=$(hostname -I | awk {print'$1'})
clientname=

docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_genconfig -u tcp://$ip
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn ovpn_init pki
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm -it kylemanna/openvpn easyrsa build-client-full $clientname
docker run -v /srv/apps/openvpn/data:/etc/openvpn --log-driver=none --rm kylemanna/openvpn ovpn_getclient $clientname > $clientname.ovpn

## DEPLOY CONTAINERS

docker-compose up -d

