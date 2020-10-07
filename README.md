# This script install secure stack web infrastructure

- OPENVPN SERVER (listen on web port with port-sharing)
- REVERSE-PROXY (provide web service backend and port-knocking authentication method)
- LNMP + PHPMYADMIN (web service backend)

this infrastructure will been deployed with docker-compose, each services will run into container.



- docker-compose.yaml.original is sample docker-compose configuration file, you must never edit this one, the script will create an exploitable config file
- To configure ports and passwords for services, you must set this parameters on config/config.json file
- when you execute script, execute in first docker installation from main menu !
