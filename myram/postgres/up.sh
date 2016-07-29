#!/usr/bin/env bash -e

base=${1}
port=${2:-5433}
printpass=${3}
extrasql=$4

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

if [[ -f "${base}/${port}/myram.lock" ]]; then
    echo "Directory "${base}/${port}"  already in use by myram";
    exit 1
fi

mkdir "${base}/${port}"
echo ${id} > "${base}/${port}/myram.lock"
mkdir "${base}/${port}/data"
mkdir "${base}/${port}/etc"
mkdir "${base}/${port}/log"
touch "${base}/${port}/log/error.log"
mkdir "${base}/${port}/run"
mkdir "${base}/${port}/tmp"

set +e
echo ${pass} > "${base}/${port}/tmp/pgpass"
initdb --username=postgres \
       --pwfile="${base}/${port}/tmp/pgpass" \
       --pgdata="${base}/${port}/data" \
       --auth-host=md5 \
       --auth-local=md5 \
       --encoding=UTF8 \
       --no-locale > /dev/null
rm "${base}/${port}/tmp/pgpass"
set -e

postgres -D "${base}/${port}/data" \
         -k "${base}/${port}/run" \
         -h 127.0.0.1 \
         -p ${port} > "${base}/${port}/log/error.log" \
         -c fsync=off -c synchronous_commit=off -c full_page_writes=off 2>&1 &

while ! grep -m1 'ready to accept connections' < "${base}/${port}/log/error.log" ; do
    echo "Waiting for the postgres daemon to start..."
    sleep 0.5
done

echo "home:       ${base}/${port}"
echo "socket:     ${base}/${port}/run"
echo "pid:        ${base}/${port}/data/postmaster.pid"
echo "port:       ${port}"
echo "dbauser:    postgres"
if [[ -n "${printpass}" ]];then
    echo "dbapass:    ${pass}"
fi
