#!/usr/bin/env bash
# $gitcmd: Path to the git executable
# $phpcmd: Path to the PHP CLI executable
# $mysqlcmd: Path to the mysql CLI executable
# $gitdir: Directory containing git repo
# $gitbranchinstalled: Branch we are going to install the DB (and upgrade to)
# $gitbranchupgraded: Branch we are going to upgrade the DB from (supports multiple, separated by commas)
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

# Verify everything is set
required="WORKSPACE gitcmd phpcmd mysqlcmd gitdir gitbranchinstalled gitbranchupgraded dblibrary dbtype dbhost1 dbuser1 dbpass1"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        # Only dbpass1 can be set and empty (because some facilities and devs like it to be empty)
        if [ "$var" != "dbpass1" ] || [ -z "${!var+x}" ]; then
            echo "Error: ${var} environment variable is not defined. See the script comments."
            exit 1
        fi
    fi
done

# Convert $gitbranchupgraded to array, so we can iterate later, keeping BC
upgradedarr=(${gitbranchupgraded//,/ })
echo "Info: Origin branches: (${#upgradedarr[@]}) $gitbranchupgraded"
echo "Info: Target branch: $gitbranchinstalled"
echo

# calculate some variables
BUILD_NUMBER="${BUILD_NUMBER:-$PPID}"
EXECUTOR_NUMBER="${EXECUTOR_NUMBER:-0}"
dbprefixinstall="cii_"
dbprefixupgrade="ciu_"
dbhost2="${dbhost2:-$dbhost1}"
dbuser2="${dbuser2:-$dbuser1}"
dbpass2="${dbpass2:-$dbpass1}"
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
currentbranch=$( cd $gitdir && $gitcmd rev-parse -q --abbrev-ref HEAD )
installdb=ci_installed_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
upgradedb=ci_upgraded_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
logfile=$WORKSPACE/compare_databases_${gitbranchinstalled}_logfile.txt
touch "${logfile}"

# Going to install the $gitbranchinstalled database
# Create the database to install
#  TODO: Based on $dbtype, execute different DB creation commands
echo "Info: Creating $installdb database" | tee -a "${logfile}"
${mysqlcmd} --user=$dbuser1 --password=$dbpass1 --host=$dbhost1 \
    --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin" 2>&1 >> "${logfile}"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error: Problem creating database $installdb" | tee -a "${logfile}"
    exit $exitstatus
fi

# Do the moodle install of $installdb
echo "Info: Installing Moodle $gitbranchinstalled into $installdb" | tee -a "${logfile}"
# Calculate the proper hash so we branch on it, no matter it's branch, tag or hash
githashinstalled=$(cd $gitdir && \
                   $gitcmd rev-parse -q --verify origin/$gitbranchinstalled || \
                   $gitcmd rev-parse -q --verify $gitbranchinstalled)
cd $gitdir && $gitcmd checkout -q -B installbranch $githashinstalled
# Use HEAD hash as admin pseudorandom password for all Moodle sites (not used).
moodleadminpass=$($gitcmd rev-list -n1 --abbrev-commit HEAD)
rm -fr config.php
${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost1 --dbname=$installdb --dbuser=$dbuser1 --dbpass=$dbpass1 --prefix=$dbprefixinstall --fullname=$installdb --shortname=$installdb --adminuser=$dbuser1 --adminpass=$moodleadminpass 2>&1 >> "${logfile}"
# Error installing, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error: Problem installing Moodle $gitbranchinstalled" | tee -a "${logfile}"
fi

# Count problematic exitstatuses
counterrors=0

# Iterate over the $upgradedarr (list of comma separated $gitbranchupgraded)
for upgrade in "${upgradedarr[@]}"; do

    echo | tee -a "${logfile}"
    echo "Info: Comparing $gitbranchinstalled and upgraded $upgrade" | tee -a "${logfile}"

    # Create the database to upgrade
    # TODO: Based on $dbtype, execute different DB creation commands
    echo "Info: Creating $upgradedb database" | tee -a "${logfile}"
    ${mysqlcmd} --user=$dbuser2 --password=$dbpass2 --host=$dbhost2 \
        --execute="CREATE DATABASE $upgradedb CHARACTER SET utf8 COLLATE utf8_bin" 2>&1 >> "${logfile}"
    # Error creating DB, we cannot continue. Exit
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error: Problem creating database $upgradedb to test upgrade" | tee -a "${logfile}"
    fi

    # Do the moodle install of $upgradedb
    # only if we don't come from an erroneus previous situation
    if [ $exitstatus -eq 0 ]; then
        echo "Info: Installing Moodle $upgrade into $upgradedb" | tee -a "${logfile}"
        # Calculate the proper hash so we branch on it, no matter it's branch, tag or hash
        githashupgrade=$(cd $gitdir && \
                           $gitcmd rev-parse -q --verify origin/$upgrade || \
                           $gitcmd rev-parse -q --verify $upgrade)
        cd $gitdir && $gitcmd checkout -q -B upgradebranch $githashupgrade
        rm -fr config.php
        ${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost2 --dbname=$upgradedb --dbuser=$dbuser2 --dbpass=$dbpass2 --prefix=$dbprefixupgrade --fullname=$upgradedb --shortname=$upgradedb --adminuser=$dbuser2 --adminpass=$moodleadminpass 2>&1 >> "${logfile}"
        # Error installing, we cannot continue. Exit
        exitstatus=${PIPESTATUS[0]}
        if [ $exitstatus -ne 0 ]; then
            echo "Error: Problem installing Moodle $upgrade to test upgrade" | tee -a "${logfile}"
        fi
    fi

    # Do the moodle upgrade
    # only if we don't come from an erroneus previous situation
    if [ $exitstatus -eq 0 ]; then
        echo "Info: Upgrading Moodle $upgrade to $gitbranchinstalled into $upgradedb" | tee -a "${logfile}"
        cd $gitdir && $gitcmd checkout -q installbranch
        ${phpcmd} admin/cli/upgrade.php --non-interactive --allow-unstable 2>&1 >> "${logfile}"
        # Error upgrading, inform and continue
        exitstatus=${PIPESTATUS[0]}
        if [ $exitstatus -ne 0 ]; then
            echo "Error: Problem upgrading from $upgrade to $gitbranchinstalled" | tee -a "${logfile}"
        fi
    fi

    # Run the DB compare utility, outputing problems if any.
    # only if we don't come from an erroneus situation on upgrade
    if [ $exitstatus -eq 0 ]; then
        echo "Info: Comparing databases $installdb and $upgradedb" | tee -a "${logfile}"
        ${phpcmd} $mydir/compare_databases.php --dblibrary=$dblibrary --dbtype=$dbtype --dbhost1=$dbhost1 --dbname1=$installdb --dbuser1=$dbuser1 --dbpass1=$dbpass1 --dbprefix1=$dbprefixinstall --dbhost2=$dbhost1 --dbname2=$upgradedb --dbuser2=$dbuser2 --dbpass2=$dbpass2 --dbprefix2=$dbprefixupgrade 2>&1 | tee -a "${logfile}"
        exitstatus=${PIPESTATUS[0]}
    fi

    # Drop the upgraded database and delete files
    # TODO: Based on $dbtype, execute different DB deletion commands
    ${mysqlcmd} --user=${dbuser2} --password=${dbpass2} --host=${dbhost2} \
        --execute="DROP DATABASE ${upgradedb}" 2>&1 >> "${logfile}"
    rm -fr config.php
    rm -fr $datadir

    # Feed the error counter
    if [ $exitstatus -ne 0 ]; then
        counterrors=$((counterrors+1))
        echo "Error: Problem comparing databases $installdb and $upgradedb" | tee -a "${logfile}"
    else
        echo "Info: OK. No problems comparing databases $installdb and $upgradedb" | tee -a "${logfile}"
    fi

done

# Drop the installed databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
${mysqlcmd} --user=${dbuser1} --password=${dbpass1} --host=${dbhost1} \
        --execute="DROP DATABASE ${installdb}" 2>&1 >> "${logfile}"
rm -fr config.php
rm -fr $datadir
$gitcmd checkout -q $currentbranch
$gitcmd branch -q -D installbranch upgradebranch

# If arrived here, return the counterrors of the php execution
echo | tee -a "${logfile}"
if [ $counterrors -ne 0 ]; then
    echo "Error: Process ended with $counterrors errors" | tee -a "${logfile}"
else
    echo "Ok: Process ended without errors" | tee -a "${logfile}"
fi
exit $counterrors
