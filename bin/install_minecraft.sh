#!/bin/bash

# Install minecraft server
sudo apt-get update
sudo apt-get install default-jdk
sudo apt-get install screen
sudo apt-get install htop
sudo mkdir /etc/minecraft
cd /etc/minecraft
sudo wget -O minecraft_server.jar https://s3.amazonaws.com/Minecraft.Download/versions/1.8.7/minecraft_server.1.8.7.jar

# Install minecraft overviewer
wget -O - http://overviewer.org/debian/overviewer.gpg.asc | sudo apt-key add -
sudo apt-get update
apt-get install minecraft-overviewer

# Install minecraft init.d script
./minecraft_service.sh

# Setup backup/map crons
./cron_setup.sh