#!/usr/bin/env zsh
trap "prog_exit" SIGQUIT SIGINT

# set program version
SYNCW_VERSION=1.0

usage()
{
    echo "Usage: syncwrun [options]"
    echo ""
    echo "Options:"
    echo "  -config configfile     : get configuration from file"
    echo "  -localdir localdir     : set local directory"
    echo "  -remotedir remotedir   : set remote directory"
    echo "  -remotehost remotehost : set remote host"
    echo "  -help                  : show this message"
    echo "  -version               : show version"

    exit
}

showversion()
{
    echo $SYNCW_VERSION
    exit
}

# get int signal and quit
prog_exit()
{
    # kill child process first
    echo "pid: $local_pid $remote_pid"
    kill -3 $local_pid
    kill -3 $remote_pid
    echo "prog exit"
    exit
}

dep_message_and_quit()
{
    echo "$1 can not found, make sure program has been installed and put in path"
    exit
}
check_dependant()
{
    # check unison
    [ -z $(which unison) ] && dep_message_and_quit "unison"
    [ -z $(which inotifywait) ] && dep_message_and_quit "inotifywait"
}

# get config from ini file
# param @configfile
getconfig()
{
    configfile=$1
    # below code copy from https://shatterealm.netlify.app/programming/2021_01_20_ini_parsing_in_shell
    while read line
    do
        # skip blank line
        [ -z "$line" ] && continue
        # Strip space
        data=$(echo "$line" | sed -e 's/^[[:space:]]*//')
        c=$(echo "$data" | cut -c1)
        if [ "$c" = "[" ]; then
            section=$(echo "$data" | grep -Po '\[\K[^]]*' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            section=$(echo "ini_$section" | sed 's/[^a-zA-Z0-9]/_/g')
        elif echo "$data" | grep -q '='; then
            # get varname and strip whitespace
            varname=$(echo "$data" | sed -e 's/=.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            # get value to be assigned and strip whitespace
            value=$(echo "$data" | sed -e 's/.*=//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # set value
            [ "$section" == "ini_local" -a "$varname" == "dir" ] && localdir=$value
            [ "$section" == "ini_remote" -a "$varname" == "dir" ] && remotedir=$value
            [ "$section" == "ini_remote" -a "$varname" == "host" ] && remotehost=$value
        fi
    done < $configfile
}

# parse argument
until [ $# -eq 0 ]
do
  name=${1:1}; shift;
  if [[ -z "$1" || $1 == -* ]] ; then eval "export $name=true"; else eval "export $name=$1"; shift; fi
done

# show usage and quit
[ -z $help ] || usage
# show version and quit
[ -z $version ] || showversion

# get config
[ -z $config ] || getconfig $config

# if can not get this variable then show help and quit
[ "#$localdir#" == "##" -o "#$remotedir#" == "##" -o "#$remotehost#" == "##" ] && usage

check_dependant

# get main program working directory
SYNC_WORKING_DIR=$(dirname $0)

#call sync local and submit to background
sh $SYNC_WORKING_DIR/syncwjob.sh LOCAL $localdir $remotedir $remotehost &
local_pid=$!

#call sync local and submit to background
sh $SYNC_WORKING_DIR/syncwjob.sh REMOTE $localdir $remotedir $remotehost &
remote_pid=$!

# wait unthil all child process quit
wait -f
