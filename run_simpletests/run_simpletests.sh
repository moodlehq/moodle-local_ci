#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $mysqlcmd: Path to the mysql CLI executable
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $dblibrary: Type of library (native, pdo...)
# $dbtype: Name of the driver (mysqli...)
# $dbhost: DB host
# $dbuser: DB user
# $dbpass: DB password
# $testpath: Path (gitdir based) we want tests to run

# Don't be strict. Script has own error control handle
set +e

# file where results will be sent
resultfile=${WORKSPACE}/run_simpletests.xml

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
installdb=ci_simpletest_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
datadir=/tmp/ci_dataroot_${BUILD_NUMBER}_${EXECUTOR_NUMBER}
dbprefixinstall="sit_"

# Going to install the $gitbranch database
# Create the database
# TODO: Based on $dbtype, execute different DB creation commands
${mysqlcmd} --user=$dbuser --password=$dbpass --host=$dbhost --execute="CREATE DATABASE $installdb CHARACTER SET utf8 COLLATE utf8_bin"
# Error creating DB, we cannot continue. Exit
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error creating database $installdb to run simpletest"
    exit $exitstatus
fi

# Do the moodle install
cd $gitdir && git checkout $gitbranch && git reset --hard origin/$gitbranch
rm -fr config.php
${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license --wwwroot="http://localhost" --dataroot="$datadir" --dbtype=$dbtype --dbhost=$dbhost --dbname=$installdb --dbuser=$dbuser --dbpass=$dbpass --prefix=$dbprefixinstall --fullname=$installdb --shortname=$installdb --adminuser=$dbuser --adminpass=$dbpass
# Error installing, we cannot continue.
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Error installing $gitbranch to run simpletest"
fi

# Execute conditionally
if [ $exitstatus -eq 0 ]; then
    # Copy the configure utility to the $gitdir
    mkdir -p $gitdir/local/ci/configure_site
    cp $mydir/../configure_site/*.php $gitdir/local/ci/configure_site/

    # Set the proper values for running generator and simpletest
    # Defaults for 2.3 and upwards
    generatordebugval=$(php -r 'echo E_ALL | E_STRICT;')
    simpletestdebugval=${generatordebugval}
    # CRAP, we cannot run E_STRICT until simpletest is updated to 1.1.0
    simpletestdebugval=$(php -r 'echo (E_ALL | E_STRICT) & ~E_STRICT;')
    # Defaults for 2.0 .. 2.2
    if [[ ${gitbranch} =~ MOODLE_(21|22)_STABLE ]]; then
        generatordebugval=38911
        simpletestdebugval=${generatordebugval}
    fi
fi

# Inject $CFG->debug in database (generator requires that)
if [ $exitstatus -eq 0 ]; then
    ${phpcmd} ${gitdir}/local/ci/configure_site/configure_site.php --rule=db,add,debug,${generatordebugval}
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error configuring the site to run simpletest"
    fi
fi

# Fill the site with some auto-generated information
if [ $exitstatus -eq 0 ]; then
    # Generator (admin/generator.php) under 21 stable is 100% borked, so ommit its execution
    if [[ ${gitbranch} =~ MOODLE_(21)_STABLE ]]; then
        echo "Generator for 21_STABLE not working, skipping"
    else
        ${phpcmd} ${gitdir}/admin/tool/generator/cli/generate.php --verbose --database_prefix=$dbprefixinstall --username=$dbuser --password=$dbpass --number_of_courses=1 --number_of_students=2 --number_of_sections=3 --number_of_modules=1 --modules_list=label --questions_per_course=0
        exitstatus=${PIPESTATUS[0]}
        if [ $exitstatus -ne 0 ]; then
            echo "Error executing generator to run simpletest"
        fi
    fi
fi

# Inject $CFG->debug in database (some branches may require different value from generator)
if [ $exitstatus -eq 0 ]; then
    ${phpcmd} ${gitdir}/local/ci/configure_site/configure_site.php --rule=db,add,debug,${simpletestdebugval}
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error configuring the site to run simpletest"
    fi
fi

# Copy the run utility to the $gitdir
if [ $exitstatus -eq 0 ]; then
    mkdir -p $gitdir/local/ci/run_simpletests
    cp $mydir/*.php $gitdir/local/ci/run_simpletests/
fi

# Execute the simpletest utility
if [ $exitstatus -eq 0 ]; then
    ${phpcmd} ${gitdir}/local/ci/run_simpletests/run_simpletests.php --format=xunit --path=${testpath} > "${resultfile}"
    exitstatus=${PIPESTATUS[0]}
fi

# Drop the databases and delete files
# TODO: Based on $dbtype, execute different DB deletion commands
${mysqlcmd} --user=${dbuser} --password=${dbpass} --host=${dbhost} \
        --execute="DROP DATABASE ${installdb}"
rm -fr config.php
rm -fr $gitdir/local/ci
rm -fr $datadir

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
