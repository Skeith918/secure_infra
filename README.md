# Script which install secure stack web infrastructure 

- OPENVPN (listen on web port with port-sharing)
- REVERSE-PROXY (provide web service backend and port-knocking authentication method)
- LDAP + RADIUS (provide authentication to infrastructure throught web) 
- LAMP + PHPMYADMIN (web service backend)

this infrastructure will been deployed with docker-compose, each services will run into container.


