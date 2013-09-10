#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $mysqlcmd: Path to the mysql CLI executable
# $gitdir: Directory containing git repo
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost: DB host
# $dbuser: DB user
# $dbpass: DB password

# Don't be strict. Script has own error control handle
set +e

# Verify everything is set
required="phpcmd mysqlcmd gitdir dblibrary dbtype dbhost dbuser dbpass"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
installdb=ci_installed_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
dbprefixinstall="cii_"

# Create the database to install
# TODO: Based on $dbtype, execute different DB creation commands
${mysqlcmd} --user=$dbuser --password=$dbpass --host=$dbhost --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $installdb to test upgrade"
    exit $exitstatus
fi

# Do the moodle install of $installdb
cd $gitdir
rm -fr config.php
${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost --dbname=$installdb --dbuser=$dbuser --dbpass=$dbpass --prefix=$dbprefixinstall --fullname=$installdb --shortname=$installdb --adminuser=$dbuser --adminpass=$dbpass > /dev/null
# Error installing, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error installing $gitbranchinstalled to test upgrade"
fi

# Copy the list_valid_components.php script to its expected
# place (local/ci/list_valid_components) and execute it from there.
# only if we don't come from an erroneus previous situation
if [ $exitstatus -eq 0 ]; then
    mkdir -p ${gitdir}/local/ci/list_valid_components
    cp ${mydir}/list_valid_components.php ${gitdir}/local/ci/list_valid_components
    ${phpcmd} ${gitdir}/local/ci/list_valid_components/list_valid_components.php \
        --basedir="${gitdir}" --absolute=true
fi

# Drop the databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
${mysqlcmd} --user=${dbuser} --password=${dbpass} --host=${dbhost} \
        --execute="DROP DATABASE ${installdb}"
rm -fr ${gitdir}/local/ci/list_valid_components/list_valid_components.php
rm -fr ${gitdir}/config.php
rm -fr ${datadir}

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
