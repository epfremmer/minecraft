#!/usr/bin/env bash

SCRIPTPATH = `pwd -P`
FILENAME   = ${SCRIPTPATH}/files/cron.txt

sudo crontab -l | cat - ${FILENAME} | sudo crontab -