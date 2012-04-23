#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost: DB host
# $dbuser: DB user
# $dbpass: DB password
# $pearpath: Path where the pear executables are available

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
dbprefixinstall="pit_"
pearbase="$( dirname ${pearpath} )"

# Going to install the $gitbranch database
# Create the database
# TODO: Based on $dbtype, execute different DB creation commands
mysql --user=$dbuser --password=$dbpass --host=$dbhost --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin"

# Do the moodle install
cd $gitdir && git checkout $gitbranch && git reset --hard origin/$gitbranch
rm -fr config.php

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
%%DATADIR%%#${datadir}"

# Apply template transformations
text="$( cat ${mydir}/config.php.template )"
for i in ${replacements}; do
    text=$( echo "${text}" | sed "s#${i}#g" )
done

# Save the config.php into destination
echo "${text}" > ${gitdir}/config.php

# Create the moodledata dir
mkdir $datadir

# Run the phpunit init script
/opt/local/bin/php ${gitdir}/admin/tool/phpunit/cli/util.php --install

# Build a new config file with all the tests
/opt/local/bin/php ${gitdir}/admin/tool/phpunit/cli/util.php --buildconfig

# Execute the phpunit utility
phpunit --log-junit "${resultfile}" | tee "${outputfile}"
exitstatus=${PIPESTATUS[0]}

# Look for any stack sent to output, it will lead to failed execution
stacks=$(grep 'Call Stack:' "${outputfile}" | wc -l)
if [[ ${stacks} -gt 0 ]]; then
    exitstatus=1
    rm "${resultfile}"
fi

# Drop the databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
mysqladmin --user=$dbuser --password=$dbpass --host=$dbhost --default-character-set=utf8 --force drop $installdb
rm -fr config.php
rm -fr $gitdir/local/ci
rm -fr $datadir

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
