#!/usr/bin/env bash

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd -P`
FILENAME=${SCRIPTPATH}/../files/cron.txt
popd > /dev/null

sudo crontab -l | cat - ${FILENAME} | sudo crontab -