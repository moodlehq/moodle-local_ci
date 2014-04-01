#!/bin/bash -e

base=${1}
port=${2:-3307}
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

mysql_install_db --user=${user} --datadir="${base}/${port}/data" >> /dev/null

conf="# myram.sh default and minimal configuration file (for a small DB).
# Edit mysql/up.sh to suit your needs.

[client]
port            = ${port}
socket          = ${base}/${port}/run/mysqld.sock

[mysqld_safe]
socket          = ${base}/${port}/run/mysqld.sock
nice            = 0

[mysqld]
user            = ${user}
pid-file        = ${base}/${port}/run/mysqld.pid
socket          = ${base}/${port}/run/mysqld.sock
port            = ${port}
datadir         = ${base}/${port}/data
tmpdir          = ${base}/${port}/tmp
log_error       = ${base}/${port}/log/error.log
skip-external-locking

bind-address            = 127.0.0.1

key_buffer              = 16M
max_allowed_packet      = 16M
thread_stack            = 192K
thread_cache_size       = 8

query_cache_limit       = 1M
query_cache_size        = 16M"

echo "${conf}" > "${base}/${port}/etc/my.cnf"

mysqld_safe --defaults-file="${base}/${port}/etc/my.cnf" >> /dev/null &
while ! grep -m1 'ready for connections' < "${base}/${port}/log/error.log" ; do
    echo "Waiting for the mysql daemon to start..."
    sleep 0.5
done

echo "home:       ${base}/${port}"
echo "socket:     ${base}/${port}/run/mysqld.sock"
echo "pid:        ${base}/${port}/run/mysqld.pid"
echo "port:       ${port}"
echo "dbauser:    root"
if [[ -n "${printpass}" ]];then
    echo "dbapass:   ${pass}"
fi

mysqladmin -S "${base}/${port}/run/mysqld.sock" --user=root password ${pass}
