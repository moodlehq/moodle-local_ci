#!/usr/bin/env bats

load libs/shared_setup

setup () {
    # These env variables must exist to get the compare_databses tests executed.
    required="LOCAL_CI_TESTS_DBLIBRARY LOCAL_CI_TESTS_DBTYPE LOCAL_CI_TESTS_DBHOST LOCAL_CI_TESTS_DBUSER LOCAL_CI_TESTS_DBPASS"
    for var in ${required}; do
        if [ -z "${!var}" ]; then
            # Only LOCAL_CI_TESTS_DBPASS can be set and empty (because some facilities and devs like it to be empty)
            if [ "$var" != "LOCAL_CI_TESTS_DBPASS" ] || [ -z "${!var+x}" ]; then
                skip "some required variables are not defined (${var})"
            fi
        fi
    done
    # Only supported database is mysqli.
    if [[ "$LOCAL_CI_TESTS_DBTYPE" != "mysqli" ]]; then
        skip "only mysqli dbtype is supported"
    fi
    # All right, populate the needed script variables.
    export dblibrary=$LOCAL_CI_TESTS_DBLIBRARY
    export dbtype=$LOCAL_CI_TESTS_DBTYPE
    export dbhost1=$LOCAL_CI_TESTS_DBHOST
    export dbuser1=$LOCAL_CI_TESTS_DBUSER
    export dbpass1=$LOCAL_CI_TESTS_DBPASS

    create_git_branch main 35d5053ba20432059b497d85e39175d356f44fb4
}

teardown () {
    echo $BATS_TEST_NAME > /tmp/file
    # Not all tests use the "compare_databases" branch.
    if [[ $BATS_TEST_NAME =~ "problems_are_detected" ]]; then
        cd $gitdir
        git checkout main
        git branch -D compare_databases -q
        cd $OLDPWD
    fi;
}

@test "compare_databases/compare_databases.sh: missing env variables" {
    export gitbranchinstalled=main
    export gitbranchupgraded=MOODLE_31_STABLE
    export dbtype=

    ci_run compare_databases/compare_databases.sh
    assert_failure
    assert_output --partial 'Error: dbtype environment variable is not defined. See the script comments.'
}

@test "compare_databases/compare_databases.sh: single actual (> 403_STABLE) branch runs work" {
    # TODO: Change this to stable branches when we have more supporting php83.
    export gitbranchinstalled=main
    export gitbranchupgraded=MOODLE_404_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial "Info: Origin branches: (1) ${gitbranchupgraded}"
    assert_output --partial "Info: Target branch: ${gitbranchinstalled}"
    assert_output --partial "Info: Installing Moodle ${gitbranchinstalled} into ci_installed_"
    assert_output --partial "Info: Comparing ${gitbranchinstalled} and upgraded ${gitbranchupgraded}"
    assert_output --partial "Info: Installing Moodle ${gitbranchupgraded} into ci_upgraded_"
    assert_output --partial "Info: Upgrading Moodle ${gitbranchupgraded} to ${gitbranchinstalled} into ci_upgraded_"
    assert_output --partial "Info: Comparing databases ci_installed_"
    assert_output --partial "Info: OK. No problems comparing databases ci_installed_"
    assert_output --partial "Ok: Process ended without errors"
    refute_output --partial "Error: Process ended with"
    run [ -f "${WORKSPACE}/compare_databases_${gitbranchinstalled}_logfile.txt" ]
    assert_success
}

@test "compare_databases/compare_databases.sh: single old (<= 404_STABLE) branch runs work" {
    # TODO: Change this to versions corresponding to different branches when we have more supporting php83-
    export gitbranchinstalled=main
    export gitbranchupgraded=v4.4.0-beta

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial "Info: Origin branches: (1) ${gitbranchupgraded}"
    assert_output --partial "Info: Target branch: ${gitbranchinstalled}"
    assert_output --partial "Info: Installing Moodle ${gitbranchinstalled} into ci_installed_"
    assert_output --partial "Info: Comparing ${gitbranchinstalled} and upgraded ${gitbranchupgraded}"
    assert_output --partial "Info: Installing Moodle ${gitbranchupgraded} into ci_upgraded_"
    assert_output --partial "Info: Upgrading Moodle ${gitbranchupgraded} to ${gitbranchinstalled} into ci_upgraded_"
    assert_output --partial "Info: Comparing databases ci_installed_"
    assert_output --partial "Info: OK. No problems comparing databases ci_installed_"
    assert_output --partial "Ok: Process ended without errors"
    refute_output --partial "Error: Process ended with"
    run [ -f "${WORKSPACE}/compare_databases_${gitbranchinstalled}_logfile.txt" ]
    assert_success
}

@test "compare_databases/compare_databases.sh: multiple branch runs work" {
    # TODO: Change this to different stable branches when we have more supporting php83.
    export gitbranchinstalled=main
    export gitbranchupgraded=v4.4.0,MOODLE_404_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial "Info: Origin branches: (2) ${gitbranchupgraded}"
    assert_output --partial "Info: Target branch: ${gitbranchinstalled}"
    assert_output --partial "Info: Comparing ${gitbranchinstalled} and upgraded v4.4.0"
    assert_output --partial "Info: Comparing ${gitbranchinstalled} and upgraded MOODLE_404_STABLE"
    assert_output --partial "Ok: Process ended without errors"
    refute_output --partial "Error: Process ended with"
    run [ -f "${WORKSPACE}/compare_databases_${gitbranchinstalled}_logfile.txt" ]
    assert_success
}

@test "compare_databases/compare_databases.sh: problems are detected" {
    # Locally, patch v4.4.0, so we introduce some differences. Then compare with upgraded v4.3.0.
    create_git_branch v4_4_0_wrong v4.4.0
    git_apply_fixture compare_databases_wrong.patch

    export gitbranchinstalled=v4_4_0_wrong
    export gitbranchupgraded=v4.3.0

    ci_run compare_databases/compare_databases.sh
    assert_failure
    assert_output --partial "Info: Origin branches: (1) ${gitbranchupgraded}"
    assert_output --partial "Info: Target branch: ${gitbranchinstalled}"
    assert_output --partial "Info: Comparing ${gitbranchinstalled} and upgraded ${gitbranchupgraded}"
    assert_output --partial "Problems found comparing databases!"
    assert_output --partial "Number of errors: 6"
    assert_output --partial "Column username of table user difference found in max_length: 200 !== 100"
    assert_output --partial "Column firstaccess of table user difference found in not_null: false !== true"
    assert_output --partial "Column firstaccess of table user difference found in default_value: 1 !== 0"
    assert_output --partial "Column trackforums of table user difference found in type: varchar !== tinyint"
    assert_output --partial "Column trackforums of table user difference found in max_length: 1 !== 2"
    assert_output --partial "Column trackforums of table user difference found in meta_type: C !== I"
    assert_output --partial "Error: Problem comparing databases ci_installed_"
    assert_output --partial "Error: Process ended with 1 errors"
    refute_output --partial "Ok: Process ended without errors"
    run [ -f "${WORKSPACE}/compare_databases_${gitbranchinstalled}_logfile.txt" ]
    assert_success
}
