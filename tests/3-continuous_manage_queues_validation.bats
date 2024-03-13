#!/usr/bin/env bats

load libs/shared_setup

setup () {
    export WORKSPACE=$gitdir

    # Some dummy variables just for the sake of the letting the script proceed through the validation.
    export jiraclicmd=jiracli
    export jiraserver=https://tracker.moodle.org
    export jirauser=jirauser
    export jirapass=jirapass
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Current date < release date" {
    releasedate=$(date -d "+10day" +%Y-%m-%d)
    lastweekdate=$(date -d "${releasedate} -7day" +%Y-%m-%d)

    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_success
    assert_output --partial "Parameters validated"
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Current date = on-sync date" {
    releasedate=$(date -d "-28day" +%Y-%m-%d)
    lastweekdate=$(date -d "${releasedate} -7day" +%Y-%m-%d)

    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_success
    assert_output --partial "Parameters validated"
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Current date > on-sync date" {
    releasedate=$(date -d "-29day" +%Y-%m-%d)
    lastweekdate=$(date -d "${releasedate} -7day" +%Y-%m-%d)

    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_failure
    assert_output --partial "ERROR: The current date is already past the on-sync period. Please make sure the Release date (${releasedate}) is configured correctly"
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Invalid release date format" {
    releasedate=$(date +%m-%d-%Y)
    lastweekdate=$(date +%Y-%m-%d)
    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_failure
    assert_output --partial "ERROR: \$releasedate. Incorrect YYYY-MM-DD format detected: ${releasedate}"
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Invalid last week date format" {
    releasedate=$(date -d "+7day" +%Y-%m-%d)
    lastweekdate=$(date +%m-%d-%Y)
    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_failure
    assert_output --partial "ERROR: \$lastweekdate. Incorrect YYYY-MM-DD format detected: ${lastweekdate}"
}

@test "tracker_automations/continuous_manage_queues/continuous_manage_queues.sh: Last week date is after the release date" {
    releasedate=$(date -d "+7day" +%Y-%m-%d)
    lastweekdate=$(date -d "+8day" +%Y-%m-%d)
    source $PWD/tracker_automations/continuous_manage_queues/lib.sh

    run run_param_validation $releasedate $lastweekdate

    # Assert result.
    assert_failure
    assert_output --partial "ERROR: The value set for \$lastweekdate ($lastweekdate) is after the \$releasedate ($releasedate)"
}
