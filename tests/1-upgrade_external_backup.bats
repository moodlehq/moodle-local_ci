#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_311_STABLE v3.11.0
}

@test "upgrade_external_backup: upgrade_external_backup_check no changes" {
    git_apply_fixture 311-upgrade_external_backup-no-changes.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run upgrade_external_backup_check/upgrade_external_backup_check.sh
    assert_success
    assert_output --partial "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
    refute_output --partial "INFO: The patch does include new tables or columns"
    assert_output --partial "INFO: OK the patch does not include new tables or columns"
    refute_output --partial "WARN"
}

@test "upgrade_external_backup: upgrade_external_backup_check all wrong" {
    git_apply_fixture 311-upgrade_external_backup-all-wrong.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run upgrade_external_backup_check/upgrade_external_backup_check.sh
    assert_success
    assert_output --partial "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: The patch does include new tables or columns"
    assert_output --partial "WARN: Database modifications (new tables or columns) detected"
    assert_output --partial "WARN: No changes detected to external functions"
    assert_output --partial "WARN: No changes detected to backup and restore"
    refute_output --partial "INFO: OK the patch includes changes to both external and backup code"
}

@test "upgrade_external_backup: upgrade_external_backup_check backup ok" {
    git_apply_fixture 311-upgrade_external_backup-backup-ok.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run upgrade_external_backup_check/upgrade_external_backup_check.sh
    assert_success
    assert_output --partial "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: The patch does include new tables or columns"
    assert_output --partial "WARN: Database modifications (new tables or columns) detected"
    assert_output --partial "WARN: No changes detected to external functions"
    refute_output --partial "WARN: No changes detected to backup and restore"
    refute_output --partial "INFO: OK the patch includes changes to both external and backup code"
}

@test "upgrade_external_backup: upgrade_external_backup_check external ok" {
    git_apply_fixture 311-upgrade_external_backup-external-ok.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run upgrade_external_backup_check/upgrade_external_backup_check.sh
    assert_success
    assert_output --partial "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: The patch does include new tables or columns"
    assert_output --partial "WARN: Database modifications (new tables or columns) detected"
    refute_output --partial "WARN: No changes detected to external functions"
    assert_output --partial "WARN: No changes detected to backup and restore"
    refute_output --partial "INFO: OK the patch includes changes to both external and backup code"
}

@test "upgrade_external_backup: upgrade_external_backup_check all ok" {
    git_apply_fixture 311-upgrade_external_backup-all-ok.patch
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER

    ci_run upgrade_external_backup_check/upgrade_external_backup_check.sh
    assert_success
    assert_output --partial "INFO: Checking for DB modifications from $initialcommit to $finalcommit"
    assert_output --partial "INFO: The patch does include new tables or columns"
    refute_output --partial "WARN: Database modifications (new tables or columns) detected"
    refute_output --partial "WARN: No changes detected to external functions"
    refute_output --partial "WARN: No changes detected to backup and restore"
    assert_output --partial "INFO: OK the patch includes changes to both external and backup code"
}
