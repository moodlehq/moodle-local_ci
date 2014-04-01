#!/bin/bash -e

base=${1}
port=${2:-5433}

if [[ -z "${base}" ]]; then
    echo "Missing base directory"
    exit 1
fi

if [[ -z "${port}" ]]; then
    echo "Missing port number"
    exit 1
fi

if [[ ! ${port} =~ ^-?[0-9]+$ ]]; then
    echo "Incorrect port number"
    exit 1
fi

base=$(dirname $(readlink -fn "${base}/myram.lock"))
user=${USER}
pass=$(perl -e "srand(18);print map{('a'..'z','A'..'Z',0..9)[int(rand(62))]}(1..16)")

if [[ ! -d "${base}" ]]; then
    echo "Base directory "${base}" does not exist";
    exit 1
fi

if [[ ! -f "${base}/${port}/myram.lock" ]]; then
    echo "Directory "${base}/${port}" not in use by myram";
    exit 1
fi

pg_ctl -W -D  "${base}/${port}/data" stop
while : ; do
    echo "Waiting for the postgres daemon to stop..."
    sleep 0.5
    [[ ! -f "${base}/${port}/data/postmaster.pid" ]] && break
done

rm -fr "${base}/${port}"
