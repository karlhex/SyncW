#!/usr/bin/env zsh

trap "prog_exit" SIGQUIT SIGINT

prog_exit()
{
    echo "child exit"
    exit
}

if [ "$1" == "REMOTE" ]; then SYNC_TYPE="REMOTE"; else SYNC_TYPE="LOCAL"; fi
LOCAL_ROOT=$2
REMOTE_ROOT=$3
REMOTE_HOST=$4

NOTIFY_LOCAL="inotifywait -e create,modify,delete $LOCAL_ROOT"
NOTIFY_REMOTE="ssh $REMOTE_HOST -C 'inotifywait -e create,modify,delete ~/$REMOTE_ROOT'"

UNISON_COMMAND="unison $LOCAL_ROOT ssh://$REMOTE_HOST/$REMOTE_ROOT"

while true
do
    # start inotifywait or inotify remote
    if [ $SYNC_TYPE == "REMOTE" ]; then
        echo ${NOTIFY_REMOTE}|awk '{run=$0;system(run)}'
    else
        echo ${NOTIFY_LOCAL}|awk '{run=$0;system(run)}'
    fi

    # if noitify program execute return error, do nothing just continue
    [ $? -ne 0 ] && continue

    # if unison is still running, continue
    [ -n $(ps -axo comm |grep unison) ] || continue

    # run unison
    echo ${UNISON_COMMAND}|awk '{run=$0;system(run)}'
    sleep 1
done
