#!/usr/bin/env bash
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to examine
# $multipleclassiserror: Does multiple classes in test file raise error or just warning (default)

# Don't be strict. Script has own error control handle
set +e

required="phpcmd gitdir gitbranch"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure we are in the desired dir and branch
cd $gitdir && git reset --quiet --hard $gitbranch && git clean -qdf

# Let's build the phpunit.xml file for further analysis.
${phpcmd} ${mydir}/create_phpunit_xml.php --basedir="${gitdir}"
exitstatus=${PIPESTATUS[0]}
if [ $exitstatus -ne 0 ]; then
    echo "Problem creating the phpunit.xml file at ${gitdir}"
    exit 1
fi

# Important! We are only interested in the test suites,
# so we need to get rid of all the coverage information from the file now.
sed -i '/<coverage>/,/<\/coverage>/d' phpunit.xml

# MDLSITE-1972. Verify that all the test directories in codebase
# are matched/covered by the definitions in the generated phpunit.xml.

# Load all the defined tests
definedtests=$(grep -r "directory suffix" ${gitdir}/phpunit.xml | sed 's/^[^>]*>\([^<]*\)<.*$/\1/g')
# Load all the existing tests
existingtests=$(cd ${gitdir} && find . -name tests | sed 's/^\.\/\(.*\)$/\1/g')
# Some well-known "tests" that we can ignore here
ignoretests=""

# Unit test classes to look for with each file (must be 1 and only 1). MDLSITE-2096
# TODO: Some day replace this with the list of abstract classes, using some classmap going up to phpunit top class.
unittestclasses="
    advanced_testcase
    area_test_base
    badgeslib_test
    base_testcase
    basic_testcase
    cachestore_tests
    core_backup_backup_restore_base_testcase
    core_reportbuilder_testcase
    data_loading_method_test_base
    data_privacy_testcase
    database_driver_testcase
    externallib_advanced_testcase
    googledocs_content_testcase
    grade_base_testcase
    lti_advantage_testcase
    messagelib_test
    mod_assign\\\\externallib_advanced_testcase
    mod_lti_testcase
    mod_quiz_attempt_walkthrough_from_csv_testcase
    mod_quiz\\\\attempt_walkthrough_from_csv_test
    provider_testcase
    qbehaviour_walkthrough_test_base
    question_attempt_upgrader_test_base
    question_testcase
    repository_googledocs_testcase
    restore_date_testcase
    route_testcase
"

# Verify that each existing test is covered by some defined test
# and that, all the test files have only one phpunit testcase class.
for existing in ${existingtests}
do
    found=""
    # Skip any existing test defined as ignoretests
    if [[ ${ignoretests} =~ ${existing} ]]; then
        echo "INFO: Ignoring ${existing}, not part of core."
        continue
    fi
    for defined in ${definedtests}
    do
        if [[ ${existing} =~ ^${defined}$ ]]; then
            echo "OK: ${existing} will be executed because there is a matching definition for it."
            found="1"
        elif [[ ${existing} =~ ^${defined}/.* ]]; then
            echo "INFO: ${existing} will be executed because the ${defined} definition covers it."
            found="1"
        fi
    done
    if [[ -z ${found} ]]; then
        # Last chance to skip, directory does not contain test units (files)
        if [[ -z $(find ${existing} -name "*_test.php") ]]; then
            echo "INFO: Ignoring ${existing}, it does not contain any test unit file."
            continue;
        fi
        echo "ERROR: ${existing} is not matched/covered by any definition in phpunit.xml !"
        exitstatus=1
    fi
    # Look inside all the test files, counting occurrences of $unittestclasses
    unittestclassesregex=$(echo ${unittestclasses} | sed 's/ /|/g')
    for testfile in $(ls ${existing} | grep "_test.php$")
    do
        # This is not the best (more accurate) regexp, but should be ok 99.99% of times.
        classcount=$(grep -iP " extends *[\\\\]?(${unittestclassesregex}) ?.* {" ${existing}/${testfile} | wc -l | xargs)
        if [[ ! ${classcount} -eq 1 ]]; then
            if [[ "${multipleclassiserror}" == "yes" ]]; then
                echo "ERROR: ${existing}/${testfile} has incorrect (${classcount}) number of unit test classes."
                exitstatus=1
            else
                echo "WARNING: ${existing}/${testfile} has incorrect (${classcount}) number of unit test classes."
            fi
        fi
    done
done

# This is everything we have added to the checkout, remove it.
rm -fr ${gitdir}/phpunit.xml

# If arrived here, return the exitstatus of the php execution
exit $exitstatus
