#!/bin/bash
# /etc/init.d/minecraft
# version 0.3.9 2012-08-13 (YYYY-MM-DD)

### BEGIN INIT INFO
# Provides:    minecraft
# Required-Start: $local_fs $remote_fs screen-cleanup
# Required-Stop:  $local_fs $remote_fs
# Should-Start:    $network
# Should-Stop:     $network
# Default-Start:  2 3 4 5
# Default-Stop:    0 1 6
# Short-Description:     Minecraft server
# Description:     Starts the minecraft server
### END INIT INFO

#Settings
SERVICE='minecraft_server.jar'
OPTIONS='nogui'
USERNAME='root'
WORLD='world'
MCPATH='/etc/minecraft'
BACKUPPATH='/etc/minecraft/bck/hourly'
BACKUPPATH_DAILY='/etc/minecraft/bck/daily'
BACKUPPATH_WEEKLY='/etc/minecraft/bck/weekly'

WORLDPATH="$MCPATH/world"
WORLDTMPPATH="$MCPATH/tmp-world"
WORLDTMPPOIPATH="$MCPATH/tmp-poi-world"
OVERVIEWER_BIN='/usr/bin/overviewer.py'
OVERVIEWER_CONFIG='/etc/minecraft/overviewer-config.py'

JAVAPATH=/usr/bin/java
MAXHEAP=3500
MINHEAP=2000
HISTORY=1024
CPU_COUNT=2
INVOCATION="$JAVAPATH -Xmx${MAXHEAP}M -Xms${MINHEAP}M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar $SERVICE $OPTIONS"

ME=$(whoami)
as_user() {
    if [ $ME == $USERNAME ] ; then
        bash -c "$1"
    else
        su - $USERNAME -c "$1"
    fi
}

mc_start() {
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        echo "$SERVICE is already running!"
    else
        echo "Starting $SERVICE..."
        cd $MCPATH
        as_user "cd $MCPATH && screen -h $HISTORY -dmS minecraft $INVOCATION"
        sleep 7
        if pgrep -u $USERNAME -f $SERVICE > /dev/null
        then
            echo "$SERVICE is now running."
        else
            echo "Error! Could not start $SERVICE!"
        fi
    fi
}

mc_saveoff() {
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        echo "$SERVICE is running... suspending saves"
        #as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP STARTING. Server going readonly...\"\015'"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-off\"\015'"
        sync
        sleep 10
    else
        echo "$SERVICE is not running. Not suspending saves."
    fi
}

mc_saveon() {
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        echo "$SERVICE is running... re-enabling saves"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-on\"\015'"
        #as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP ENDED. Server going read-write...\"\015'"
    else
        echo "$SERVICE is not running. Not resuming saves."
    fi
}

mc_stop() {
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        echo "Stopping $SERVICE"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
        sleep 10
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'"
        sleep 20
    else
        echo "$SERVICE was not running."
    fi

    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        echo "Error! $SERVICE could not be stopped."
    else
        echo "$SERVICE is stopped."
    fi
}

mc_backup() {
    echo $(date)
    mc_saveoff

    NOW=$(date "+%Y%m%d_%H%M")
    BACKUP_FILE="$BACKUPPATH/${WORLD}_${NOW}.tar"
    CONFIG_FILES="banned-ips.json banned-players.json ops.json server.properties whitelist.json"

    if [ -e "$MCPATH/overviewer-config.py" ]; then
        CONFIG_FILES+=" overviewer-config.py"
    fi

    echo "Backing up minecraft world..."
    as_user "/usr/bin/nice -n 19 tar -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD $CONFIG_FILES"

    mc_saveon

    #echo "Compressing backup..."
    #as_user "gzip -f \"$BACKUP_FILE\""

    echo "Removing backups older than 3 days..."
    as_user "find \"$BACKUPPATH\" -type f -name \"world_20*.tar*\" -mtime +2 -exec rm -v {} \;"

    echo "Done."
}

mc_backup_daily() {
    echo $(date)
    echo "Moving latest hourly backup to daily dir..."
    latest=$(ls -rt $BACKUPPATH/world_20*.tar* | tail -1)
    if [ -e "$latest" ]; then
        as_user "mv -v \"$latest\" \"$BACKUPPATH_DAILY\""

        echo "Removing daily backups older than 5 days..."
        as_user "find \"$BACKUPPATH_DAILY\" -type f -name \"world_20*.tar*\" -mtime +4 -exec rm -v {} \;"
    else
        echo "No current backup files found."
    fi
}

mc_backup_weekly() {
    echo $(date)
    echo "Moving latest hourly backup to weekly dir..."
    latest=$(ls -rt $BACKUPPATH/world_20*.tar* | tail -1)
    if [ -e "$latest" ]; then
        as_user "mv -v \"$latest\" \"$BACKUPPATH_WEEKLY\""

        echo "Removing weekly backups older than 21 days..."
        as_user "find \"$BACKUPPATH_WEEKLY\" -type f -name \"world_20*.tar*\" -mtime +20 -exec rm -v {} \;"
    else
        echo "No current backup files found."
    fi
}

mc_command() {
    command="$1";
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
        pre_log_len=$(wc -l "$MCPATH/logs/latest.log" | awk '{print $1}')
        echo "$SERVICE is running... executing command"
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"$command\"\015'"
        sleep .1 # assumes cmd will run and print to log file in < .1 seconds
        tail -n $[$(wc -l "$MCPATH/logs/latest.log" | awk '{print $1}')-$pre_log_len] "$MCPATH/logs/latest.log"
    fi
}

mc_generate_map() {
    # Handle --genpoi arg
    if [ -n "$1" -a "$1" == "--genpoi" ]; then
        echo "Generating markers only..."
        # For the markers, we make a copy of the config file, replacing the
        # location of the world location, so it doesn't interfere with the map
        # generation
        echo -n "Copying world to temp dir '$WORLDTMPPOIPATH'..."
        as_user "cp -p -r \"$WORLDPATH\" \"$WORLDTMPPOIPATH\""
        echo "done."

        sed 's/tmp-world/tmp-poi-world/' "$OVERVIEWER_CONFIG" > /tmp/overviewer-poi-config.py
        echo -n "Running overviewer..."
        as_user "/usr/bin/nice -n 19 \"$OVERVIEWER_BIN\" --quiet -c /tmp/overviewer-poi-config.py --genpoi"
        echo "done."

        # Delete temp world dir
        echo -n "Deleting temp world '$WORLDTMPPOIPATH'..."
        as_user "rm -rf \"$WORLDTMPPOIPATH\""
        echo "done."

        # Clean up tmp config
        rm /tmp/overviewer-poi-config.py
    else
        echo -n "Copying world to temp dir '$WORLDTMPPATH'..."
        as_user "cp -p -r \"$WORLDPATH\" \"$WORLDTMPPATH\""
        echo "done."

        as_user "screen -p 0 -S minecraft -X eval 'stuff \"say Generating overview map...\"\015'"
        as_user "/usr/bin/nice -n 19 \"$OVERVIEWER_BIN\" -p 1 -c \"$OVERVIEWER_CONFIG\""
        as_user "screen -p 0 -S minecraft -X eval 'stuff \"say Map generation complete\"\015'"

        # Delete temp world dir
        echo -n "Deleting temp world '$WORLDTMPPATH'..."
        as_user "rm -rf \"$WORLDTMPPATH\""
        echo "done."
    fi
}

#Start-Stop here
case "$1" in
    start)
        mc_start
        ;;
    stop)
        mc_stop
        ;;
    restart)
        mc_stop
        mc_start
        ;;
    update)
        mc_stop
        mc_backup
        mc_update $2
        mc_start
        ;;
    backup)
        mc_backup
        ;;
    backup_daily)
        mc_backup_daily
        ;;
    backup_weekly)
        mc_backup_weekly
        ;;
    status)
        if pgrep -u $USERNAME -f $SERVICE > /dev/null
        then
            echo "$SERVICE is running."
        else
            echo "$SERVICE is not running."
        fi
        ;;
    command)
        if [ $# -gt 1 ]; then
            shift
            mc_command "$*"
        else
            echo "Must specify server command (try 'help'?)"
        fi
        ;;
    genmap)
        mc_generate_map
        ;;
    genpoi)
        mc_generate_map --genpoi
        ;;

    *)
        echo "Usage: $0 {start|stop|backup|backup_daily|backup_weekly|status|restart|command <arg>|genmap|genpoi}"
        exit 1
        ;;
esac

exit 0