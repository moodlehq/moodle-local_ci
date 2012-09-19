#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $mysqlcmd: Path to the mysql CLI executable
# $gitdir: Directory containing git repo
# $gitbranchinstalled: Branch we are going to install the DB (and upgrade to)
# $gitbranchupgraded: Branch we are going to upgrade the DB from
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost1: DB1 host
# $dbhost2: DB2 host (optional)
# $dbuser1: DB1 user
# $dbuser2: DB2 user (optional)
# $dbpass1: DB1 password
# $dbpass2: DB2 password (optional)

# Don't be strict. Script has own error control handle
set +e

# file where results will be sent
resultfile=$WORKSPACE/compare_databases_${gitbranchinstalled}_${gitbranchupgraded}.txt

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
installdb=ci_installed_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
upgradedb=ci_upgraded_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
dbprefixinstall="cii_"
dbprefixupgrade="ciu_"
if [[ -z "$dbhost2" ]]
then
    dbhost2=$dbhost1
fi
if [[ -z "$dbuser2" ]]
then
    dbuser2=$dbuser1
fi
if [[ -z "$dbpass2" ]]
then
    dbpass2=$dbpass1
fi

# Going to install the $gitbranchinstalled database
# Create the database to install
# TODO: Based on $dbtype, execute different DB creation commands
${mysqlcmd} --user=$dbuser1 --password=$dbpass1 --host=$dbhost1 --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $installdb to test upgrade"
    exit $exitstatus
fi

# Create the database to upgrade
# TODO: Based on $dbtype, execute different DB creation commands
${mysqlcmd} --user=$dbuser1 --password=$dbpass1 --host=$dbhost1 --execute="CREATE DATABASE $upgradedb CHARACTER SET utf8 COLLATE utf8_bin"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $upgradedb to test upgrade"
    exit $exitstatus
fi

# Do the moodle install of $installdb
cd $gitdir && git checkout $gitbranchinstalled && git reset --hard origin/$gitbranchinstalled
rm -fr config.php
${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost1 --dbname=$installdb --dbuser=$dbuser1 --dbpass=$dbpass1 --prefix=$dbprefixinstall --fullname=$installdb --shortname=$installdb --adminuser=$dbuser1 --adminpass=$dbpass1
# Error installing, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error installing $gitbranchinstalled to test upgrade"
fi

# Going to install and upgrade the $gitbranchupgraded database

# Do the moodle install of $upgradedb
# only if we don't come from an erroneus previous situation
if [ $exitstatus -eq 0 ]; then
    cd $gitdir && git checkout $gitbranchupgraded && git reset --hard origin/$gitbranchupgraded
    rm -fr config.php
    ${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost2 --dbname=$upgradedb --dbuser=$dbuser2 --dbpass=$dbpass2 --prefix=$dbprefixupgrade --fullname=$upgradedb --shortname=$upgradedb --adminuser=$dbuser2 --adminpass=$dbpass2
    # Error installing, we cannot continue. Exit
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error installing $gitbranchupgraded to test upgrade"
    fi
fi

# Do the moodle upgrade
# only if we don't come from an erroneus previous situation
if [ $exitstatus -eq 0 ]; then
    cd $gitdir && git checkout $gitbranchinstalled && git reset --hard origin/$gitbranchinstalled
    ${phpcmd} admin/cli/upgrade.php --non-interactive --allow-unstable
    # Error upgrading, inform and continue
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error upgrading from $gitbranchupgraded to $gitbranchinstalled"
    fi
fi

# Run the DB compare utility, saving results to file
# only if we don't come from an erroneus situation on upgrade
if [ $exitstatus -eq 0 ]; then
    ${phpcmd} $mydir/compare_databases.php --dblibrary=$dblibrary --dbtype=$dbtype --dbhost1=$dbhost1 --dbname1=$installdb --dbuser1=$dbuser1 --dbpass1=$dbpass1 --dbprefix1=$dbprefixinstall --dbhost1=$dbhost1 --dbname2=$upgradedb --dbuser2=$dbuser2 --dbpass2=$dbpass2 --dbprefix2=$dbprefixupgrade > "$resultfile"
    exitstatus=${PIPESTATUS[0]}
fi

# Drop the databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
${mysqlcmd} --user=${dbuser1} --password=${dbpass1} --host=${dbhost1} \
        --execute="DROP DATABASE ${installdb}"
${mysqlcmd} --user=${dbuser2} --password=${dbpass2} --host=${dbhost2} \
        --execute="DROP DATABASE ${upgradedb}"
rm -fr config.php
rm -fr $datadir

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
