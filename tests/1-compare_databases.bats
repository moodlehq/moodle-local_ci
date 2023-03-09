#!/usr/bin/env bats

load libs/shared_setup

setup () {
    # These env variables must exist to get the compare_databses tests executed.
    required="LOCAL_CI_TESTS_DBLIBRARY LOCAL_CI_TESTS_DBTYPE LOCAL_CI_TESTS_DBHOST LOCAL_CI_TESTS_DBUSER LOCAL_CI_TESTS_DBPASS"
    for var in ${required}; do
        if [ -z "${!var}" ]; then
            # Only LOCAL_CI_TESTS_DBPASS can be set and empty (because some facilities and devs like it to be empty)
            if [ "$var" != "LOCAL_CI_TESTS_DBPASS" ] || [ -z "${!var+x}" ]; then
                skip "some required variables are not defined"
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

    create_git_branch master 35d5053ba20432059b497d85e39175d356f44fb4
}

@test "compare_databases/compare_databases.sh: missing env variables" {
    export gitbranchinstalled=master
    export gitbranchupgraded=MOODLE_31_STABLE
    export dbtype=

    ci_run compare_databases/compare_databases.sh
    assert_failure
    assert_output --partial 'Error: dbtype environment variable is not defined. See the script comments.'
}

@test "compare_databases/compare_databases.sh: single actual (>= 39_STABLE) branch runs work" {
    export gitbranchinstalled=MOODLE_401_STABLE
    export gitbranchupgraded=MOODLE_39_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (1) MOODLE_39_STABLE'
    assert_output --partial 'Info: Target branch: MOODLE_401_STABLE'
    assert_output --partial 'Info: Installing Moodle MOODLE_401_STABLE into ci_installed_'
    assert_output --partial 'Info: Comparing MOODLE_401_STABLE and upgraded MOODLE_39_STABLE'
    assert_output --partial 'Info: Installing Moodle MOODLE_39_STABLE into ci_upgraded_'
    assert_output --partial 'Info: Upgrading Moodle MOODLE_39_STABLE to MOODLE_401_STABLE into ci_upgraded_'
    assert_output --partial 'Info: Comparing databases ci_installed_'
    assert_output --partial 'Info: OK. No problems comparing databases ci_installed_'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_MOODLE_401_STABLE_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: single old (< 311_STABLE) branch runs work" {
    export gitbranchinstalled=v3.11.8
    export gitbranchupgraded=v3.11.1

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (1) v3.11.1'
    assert_output --partial 'Info: Target branch: v3.11.8'
    assert_output --partial 'Info: Installing Moodle v3.11.8 into ci_installed_'
    assert_output --partial 'Info: Comparing v3.11.8 and upgraded v3.11.1'
    assert_output --partial 'Info: Installing Moodle v3.11.1 into ci_upgraded_'
    assert_output --partial 'Info: Upgrading Moodle v3.11.1 to v3.11.8 into ci_upgraded_'
    assert_output --partial 'Info: Comparing databases ci_installed_'
    assert_output --partial 'Info: OK. No problems comparing databases ci_installed_'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_v3.11.8_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: multiple branch runs work" {
    export gitbranchinstalled=MOODLE_401_STABLE
    export gitbranchupgraded=MOODLE_39_STABLE,MOODLE_310_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (2) MOODLE_39_STABLE,MOODLE_310_STABLE'
    assert_output --partial 'Info: Target branch: MOODLE_401_STABLE'
    assert_output --partial 'Info: Comparing MOODLE_401_STABLE and upgraded MOODLE_39_STABLE'
    assert_output --partial 'Info: Comparing MOODLE_401_STABLE and upgraded MOODLE_310_STABLE'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_MOODLE_401_STABLE_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: problems are detected" {
    export gitbranchinstalled=3ba580e3f2a5f253365d33642b0bb6a94285ba2c
    export gitbranchupgraded=MOODLE_311_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_failure
    assert_output --partial 'Info: Origin branches: (1) MOODLE_311_STABLE'
    assert_output --partial 'Info: Target branch: 3ba580e3f2a5f253365d33642b0bb6a94285ba2c'
    assert_output --partial 'Info: Comparing 3ba580e3f2a5f253365d33642b0bb6a94285ba2c and upgraded MOODLE_311_STABLE'
    assert_output --partial 'Problems found comparing databases!'
    assert_output --partial 'Number of errors: 7'
    assert_output --partial 'Column status of table enrol_lti_app_registration difference found in has_default: true !== false'
    assert_output --partial 'Column status of table enrol_lti_app_registration difference found in default_value: 0 !== null'
    assert_output --partial 'Column hidden of table grade_categories difference found in type: tinyint !== bigint'
    assert_output --regexp 'Column hidden of table grade_categories difference found in max_length: 2 !== 1[89]'
    assert_output --partial 'Column hidden of table grade_categories_history difference found in type: tinyint !== bigint'
    assert_output --regexp 'Column hidden of table grade_categories_history difference found in max_length: 2 !== 1[89]'
    assert_output --partial 'Index (pathnamehash) of table h5p only available in second DB'
    assert_output --partial 'Error: Problem comparing databases ci_installed_'
    assert_output --partial 'Error: Process ended with 1 errors'
    refute_output --partial 'Ok: Process ended without errors'
    run [ -f $WORKSPACE/compare_databases_3ba580e3f2a5f253365d33642b0bb6a94285ba2c_logfile.txt ]
    assert_success
}
