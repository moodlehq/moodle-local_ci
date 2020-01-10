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

@test "compare_databases/compare_databases.sh: single actual (>= 35_STABLE) branch runs work" {
    export gitbranchinstalled=master
    export gitbranchupgraded=MOODLE_35_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (1) MOODLE_35_STABLE'
    assert_output --partial 'Info: Target branch: master'
    assert_output --partial 'Info: Installing Moodle master into ci_installed_'
    assert_output --partial 'Info: Comparing master and upgraded MOODLE_35_STABLE'
    assert_output --partial 'Info: Installing Moodle MOODLE_35_STABLE into ci_upgraded_'
    assert_output --partial 'Info: Upgrading Moodle MOODLE_35_STABLE to master into ci_upgraded_'
    assert_output --partial 'Info: Comparing databases ci_installed_'
    assert_output --partial 'Info: OK. No problems comparing databases ci_installed_'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_master_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: single old (< 35_STABLE) branch runs work" {
    export gitbranchinstalled=v3.4.5
    export gitbranchupgraded=v3.4.1

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (1) v3.4.1'
    assert_output --partial 'Info: Target branch: v3.4.5'
    assert_output --partial 'Info: Installing Moodle v3.4.5 into ci_installed_'
    assert_output --partial 'Info: Comparing v3.4.5 and upgraded v3.4.1'
    assert_output --partial 'Info: Installing Moodle v3.4.1 into ci_upgraded_'
    assert_output --partial 'Info: Upgrading Moodle v3.4.1 to v3.4.5 into ci_upgraded_'
    assert_output --partial 'Info: Comparing databases ci_installed_'
    assert_output --partial 'Info: OK. No problems comparing databases ci_installed_'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_v3.4.5_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: multiple branch runs work" {
    export gitbranchinstalled=master
    export gitbranchupgraded=MOODLE_36_STABLE,MOODLE_37_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_success
    assert_output --partial 'Info: Origin branches: (2) MOODLE_36_STABLE,MOODLE_37_STABLE'
    assert_output --partial 'Info: Target branch: master'
    assert_output --partial 'Info: Comparing master and upgraded MOODLE_36_STABLE'
    assert_output --partial 'Info: Comparing master and upgraded MOODLE_37_STABLE'
    assert_output --partial 'Ok: Process ended without errors'
    refute_output --partial 'Error: Process ended with'
    run [ -f $WORKSPACE/compare_databases_master_logfile.txt ]
    assert_success
}

@test "compare_databases/compare_databases.sh: problems are detected" {
    skip # FIXME: MDLSITE-4769 temporarily skipped, to save wasting time on a busy week.
    export gitbranchinstalled=ccee2dc2c5ad983bf0b10716a1f627664e3dc023
    export gitbranchupgraded=MOODLE_31_STABLE

    ci_run compare_databases/compare_databases.sh
    assert_failure
    assert_output --partial 'Info: Origin branches: (1) MOODLE_31_STABLE'
    assert_output --partial 'Info: Target branch: ccee2dc2c5ad983bf0b10716a1f627664e3dc023'
    assert_output --partial 'Info: Comparing ccee2dc2c5ad983bf0b10716a1f627664e3dc023 and upgraded MOODLE_31_STABLE'
    assert_output --partial 'Problems found comparing databases!'
    assert_output --partial 'Number of errors: 3'
    assert_output --partial 'Column completionstatusallscos of table scorm difference found in not_null: false !== true'
    assert_output --partial 'Column completionstatusallscos of table scorm difference found in has_default: false !== true'
    assert_output --partial 'Column completionstatusallscos of table scorm difference found in default_value: null !== 0'
    assert_output --partial 'Error: Problem comparing databases ci_installed_'
    assert_output --partial 'Error: Process ended with 1 errors'
    refute_output --partial 'Ok: Process ended without errors'
    run [ -f $WORKSPACE/compare_databases_ccee2dc2c5ad983bf0b10716a1f627664e3dc023_logfile.txt ]
    assert_success
}
