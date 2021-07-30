#!/bin/bash

#update ubuntu
sudo apt update -y

#install java
sudo apt install default-jre

#install Tomcat
sudo apt install tomcat8
sudo systemctl start tomcat8