# Minecraft Server

## AWS Setup Scripts

### Requirements

* ubuntu 14.04
* sudo permissions

### Description

Contains some basic bash scripts used to provision a new AWS EC2 instance running ubuntu with a new Minecraft server.

Includes automatic installation/generation of:

* Minecraft Server
* Minecraft Overviewer (map)
* Minecraft Service

### Installation

Download and run the installation script

* Clone the repo `git clone git@github.com:epfremmer/minecraft.git`
* Go to root directory `cd minecraft` 
* Run install script `bin/install`

### Service Usage

After the install script has added the minecraft service script you can manage your server using the service by running.

    sudo service minecraft ${COMMAND_NAME}

Available Commands:

* help: Display usage information
* start: Start the server
* stop: Stop the server
* backup: Backup the current server
* backup_daily: Archive daily backup files
* backup_weekly: Archive weekly backup files
* status: Report the current server status
* restart: Restart the server
* command: Execute a Mincraft terminal command