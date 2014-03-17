#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $psqlcmd: Path to the psql CLI executable
# $mysqlcmd: Path to the mysql CLI executable
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost: DB host
# $dbuser: DB user
# $dbpass: DB password
# $multipleclassiserror: Does multiple classes in test file
#                        raise error or just warning (dlft).

# Don't be strict. Script has own error control handle
set +e

# file to capture execution output
outputfile=${WORKSPACE}/run_phpunittests.out
# file where results will be sent
resultfile=${WORKSPACE}/run_phpunittests.xml

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
installdb=ci_phpunit_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadirphpunit=/tmp/ci_dataroot_phpunit_${BUILD_NUMBER}_${EXECUTOR_NUMBER}

# prepare the composer stuff needed to run this job
. ${mydir}/../prepare_composer_stuff/prepare_composer_stuff.sh

# Going to install the $gitbranch database
# Create the database
# Based on $dbtype, execute different DB creation commands (mysqli, pgsql)
if [[ "${dbtype}" == "pgsql" ]]; then
    export PGPASSWORD=${dbpass}
    ${psqlcmd} -h ${dbhost} -U ${dbuser} -d template1 \
        -c "CREATE DATABASE ${installdb} ENCODING 'utf8'"
elif [[ "${dbtype}" == "mysqli" ]]; then
    ${mysqlcmd} --user=${dbuser} --password=${dbpass} --host=${dbhost} \
        --execute="CREATE DATABASE ${installdb} CHARACTER SET utf8 COLLATE utf8_bin"
else
    echo "Error: Incorrect dbtype=${dbtype}"
    exit 1
fi
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $installdb to run phpunit tests"
    exit $exitstatus
fi

# Do the moodle install
cd $gitdir && git reset --hard $gitbranch
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

# MDLSITE-1972. Verify that all the test directories in codebase
# are matched/covered by the definitions in the generated phpunit.xml.
# Any error will stop execution and fail the job.

# Load all the defined tests
definedtests=$(grep -r "directory suffix" ${gitdir}/phpunit.xml | sed 's/^[^>]*>\([^<]*\)<.*$/\1/g')
# Load all the existing tests
existingtests=$(cd ${gitdir} && find . -name tests | sed 's/^\.\/\(.*\)$/\1/g')
# Some well-known "tests" that we can ignore here
ignoretests="local/codechecker/pear/PHP/tests lib/phpexcel/PHPExcel/Shared/JAMA/tests"
# Unit test classes to look for with each file (must be 1 and only 1). MDLSITE-2096
# TODO: Some day replace this with the list of abstract classes, from PHPUnit_Framework_TestCase using some classmap
unittestclasses="basic_testcase advanced_testcase database_driver_testcase externallib_advanced_testcase data_loading_method_test_base question_testcase question_attempt_upgrader_test_base qbehaviour_walkthrough_test_base grade_base_testcase"

# Verify that each existing test is covered by some defined test
# and that, all the test files have only one phpunit testcase class.
for existing in ${existingtests}
do
    found=""
    # Skip any existing test defined as ignoretests
    if [[ ${ignoretests} =~ ${existing} ]]; then
        echo "NOTE: Ignoring ${existing}, not part of core."
        continue
    fi
    for defined in ${definedtests}
    do
        if [[ ${existing} =~ ^${defined}$ ]]; then
            echo "OK: ${existing} will be executed because there is a matching definition for it."
            found="1"
        elif [[ ${existing} =~ ^${defined}/.* ]]; then
            echo "NOTE: ${existing} will be executed because the ${defined} definition covers it."
            found="1"
        fi
    done
    if [[ -z ${found} ]]; then
        # Last chance to skip, directory does not contain test units (files)
        if [[ -z $(ls ${existing} | grep "_test.php$") ]]; then
            echo "NOTE: Ignoring ${existing}, does not contain any test unit file."
            continue;
        fi
        echo "ERROR: ${existing} is not matched/covered by any definition in phpunit.xml !"
        exitstatus=1
    fi
    # Look inside all the test files, counting occurrences of $unittestclasses
    unittestclassesregex=$(echo ${unittestclasses} | sed 's/ /|/g')
    for testfile in $(ls ${existing} | grep "_test.php$")
    do
        classcount=$(grep -iP " extends *(${unittestclassesregex}) *{" ${existing}/${testfile} | wc -l)
        if [[ ! ${classcount} -eq 1 ]]; then
            echo "WARNING: ${existing}/${testfile} has incorrect (${classcount}) number of unit test classes."
            if [[ "${multipleclassiserror}" == "yes" ]]; then
                exitstatus=1
            fi
        fi
    done
done

# Execute the phpunit utility
# Conditionally
if [ $exitstatus -eq 0 ]; then
    which phpunit
    phpunit --log-junit "${resultfile}" 2>&1 | tee "${outputfile}"
    exitstatus=${PIPESTATUS[0]}
fi

# Look for any stack sent to output, it will lead to failed execution
# Conditionally
if [ $exitstatus -eq 0 ]; then
    # notices/warnings/errors under simpletest (phpunit captures them)
    stacks=$(grep 'Call Stack:' "${outputfile}" | wc -l)
    if [[ ${stacks} -gt 0 ]]; then
        echo "ERROR: uncontrolled notice/warning/error output on execution."
        exitstatus=1
        rm "${resultfile}"
    fi
    # debugging messages
    debugging=$(grep 'Debugging:' "${outputfile}" | wc -l)
    if [[ ${debugging} -gt 0 ]]; then
        echo "ERROR: uncontrolled debugging output on execution."
        exitstatus=1
        rm "${resultfile}"
    fi
    # general backtrace information
    backtrace=$(grep 'line [0-9]* of .*: call to' "${outputfile}" | wc -l)
    if [[ ${backtrace} -gt 0 ]]; then
        echo "ERROR: uncontrolled backtrace output on execution."
        exitstatus=1
        rm "${resultfile}"
    fi
    # anything exceptional (not dots and numbers) in the execution lines.
    exceptional=$(grep -P '^\.|%\)$' "${outputfile}" | grep -vP '^[\.SIEF]*[ \d/\(\)%]*$' | wc -l)
    if [[ ${exceptional} -gt 0 ]]; then
        echo "ERROR: uncontrolled exceptional output on execution."
        exitstatus=1
        rm "${resultfile}"
    fi
fi

# Drop the databases and delete files
# Based on $dbtype, execute different DB deletion commands (pgsql, mysqli)
if [[ "${dbtype}" == "pgsql" ]]; then
    export PGPASSWORD=${dbpass}
    ${psqlcmd} -h ${dbhost} -U ${dbuser} -d template1 \
        -c "DROP DATABASE ${installdb}"
elif [[ "${dbtype}" == "mysqli" ]]; then
    ${mysqlcmd} --user=${dbuser} --password=${dbpass} --host=${dbhost} \
        --execute="DROP DATABASE ${installdb}"
else
    echo "Error: Incorrect dbtype=${dbtype}"
    exit 1
fi
rm -fr config.php
rm -fr $gitdir/local/ci
rm -fr ${datadir}
rm -fr ${datadirphpunit}

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
