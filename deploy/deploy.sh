#!/bin/sh

BASE=`pwd`
APP_NAME=`basename $BASE`
TARBALL="${APP_NAME}.tgz"

function do_usage() {
    echo "$0 --to=<host> [--user=<user>] [--ssh-port=<port>]"
    echo "$0 --check --to=<host> [--user=<user>] [--ssh-port=<port>]"
}

function do_check() {
    to=$1; user=$2; port=$3

    if [[ -z "$user" ]]; then
        user=`id -un`
    fi
    if [[ -z "$port" ]]; then
        port=22
    fi

    echo "Based on your provided arguments, this script assumes that:"
    grep -e 'ASSUMPTION[:]' $0 | \
        sed -e "s/APP_NAME/$APP_NAME/g" | \
        sed -e "s/DEPLOYER/$user/g" | \
        sed -e "s/.*# ASSUMPTION[:]/ */g"
}

function do_run() {
    to=$1; user=$2; port=$3

    if [[ ! -f "${APP_NAME}.tgz" ]]; then
        echo "${APP_NAME}.tgz not found, please run 'npm run bundle-pack'"
        exit
    fi

    if [[ -z "$user" ]]; then
        user=`id -un`
    fi
    if [[ -z "$port" ]]; then
        port=22
    fi

    echo "Deploying $TARBALL => $user@$to:$port:/apps/$APP_NAME"
    # ASSUMPTION: APP_NAME is deployed to /apps/APP_NAME
    # ASSUMPTION: /apps/APP_NAME is writable by DEPLOYER
    cat $TARBALL | ssh -p $port $user@$to tar -C /apps/$APP_NAME --strip-components 1 -xzf -

    echo "Configuring Upstart job: $APP_NAME"
    # ASSUMPTION: /etc/init/APP_NAME.conf is writable by deploying user
    cat deploy/upstart.conf | \
        sed -e "s/APP_NAME/$APP_NAME/g" | \
        sed -e "s/DEPLOYER/$user/g" | \
        ssh -p $port $user@$to "cat - > /etc/init/${APP_NAME}.conf"

    echo "Reloading/Restarting/Starting Upstart job: $APP_NAME"
    # ASSUMPTION: DEPLOYER has sudo permission to run /sbin/initctl
    ssh -p $port $user@$to "sudo /sbin/initctl reload $APP_NAME; \
                          sudo /sbin/initctl restart $APP_NAME || \
                          sudo /sbin/initctl start $APP_NAME"
}

if [[ -z "$npm_config_to" ]]; then
    do_usage
elif [[ -n "$npm_config_check" ]]; then
    do_check $npm_config_to $npm_config_as $npm_config_ssh_port
else
    do_run $npm_config_to $npm_config_as $npm_config_ssh_port
fi
