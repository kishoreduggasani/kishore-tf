#!/bin/bash

##update ubuntu
sudo apt update -y

#install java
sudo apt install default-jre -y

#install Tomcat
sudo apt install tomcat8 -y
sudo systemctl start tomcat8
