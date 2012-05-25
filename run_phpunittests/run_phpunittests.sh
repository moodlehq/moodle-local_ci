#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost: DB host
# $dbuser: DB user
# $dbpass: DB password
# $pearpath: Path where the pear executables are available

# Don't be strict. Script has own error control handle
set +e

# file to capture execution output
outputfile=${WORKSPACE}/run_phpunittests.out
# file where results will be sent
resultfile=${WORKSPACE}/run_phpunittests.xml

# add the PEAR path
PATH="$PATH:/opt/local/bin/:$pearpath"; export PATH

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
installdb=ci_phpunit_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadirphpunit=/tmp/ci_dataroot_phpunit_${BUILD_NUMBER}_${EXECUTOR_NUMBER}

# Going to install the $gitbranch database
# Create the database
# TODO: Based on $dbtype, execute different DB creation commands
mysql --user=$dbuser --password=$dbpass --host=$dbhost --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $installdb to run phpunit tests"
    exit $exitstatus
fi

# Do the moodle install
cd $gitdir && git checkout $gitbranch && git reset --hard origin/$gitbranch
rm -fr config.php
rm -fr ${resultfile}

# To execute the phpunit tests we don't need a real site installed, just the phpunit-prefixed one.
# For now we are using one template config.php containing all the required vars and then we run the init shell script
# But surely all those vars will be configured via params soon (stage 4/5 of migration to phpunit)
# So, until then, let's create the config.php based on template
replacements="%%DBLIBRARY%%#${dblibrary}
%%DBTYPE%%#${dbtype}
%%DBHOST%%#${dbhost}
%%DBUSER%%#${dbuser}
%%DBPASS%%#${dbpass}
%%DBNAME%%#${installdb}
%%DATADIR%%#${datadir}
%%DATADIRPHPUNIT%%#${datadirphpunit}"

# Apply template transformations
text="$( cat ${mydir}/config.php.template )"
for i in ${replacements}; do
    text=$( echo "${text}" | sed "s#${i}#g" )
done

# Save the config.php into destination
echo "${text}" > ${gitdir}/config.php

# Create the moodledata dir
mkdir ${datadir}
mkdir ${datadirphpunit}

# Run the phpunit init script
${phpcmd} ${gitdir}/admin/tool/phpunit/cli/util.php --install
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error installing database $installdb to run phpunit tests"
fi

# Build a new config file with all the tests
# Conditionally
if [ $exitstatus -eq 0 ]; then
    ${phpcmd} ${gitdir}/admin/tool/phpunit/cli/util.php --buildconfig
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error building config to run phpunit tests"
    fi
fi

# Execute the phpunit utility
# Conditionally
if [ $exitstatus -eq 0 ]; then
    phpunit --log-junit "${resultfile}" | tee "${outputfile}"
    exitstatus=${PIPESTATUS[0]}
fi

# Look for any stack sent to output, it will lead to failed execution
# Conditionally
if [ $exitstatus -eq 0 ]; then
    stacks=$(grep 'Call Stack:' "${outputfile}" | wc -l)
    if [[ ${stacks} -gt 0 ]]; then
        exitstatus=1
        rm "${resultfile}"
    fi
fi

# Drop the databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
mysqladmin --user=$dbuser --password=$dbpass --host=$dbhost --default-character-set=utf8 --force drop $installdb
rm -fr config.php
rm -fr $gitdir/local/ci
rm -fr ${datadir}
rm -fr ${datadirphpunit}

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
