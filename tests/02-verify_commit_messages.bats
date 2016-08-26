#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0
    export issuecode="MDL-12345"
}

commit_apply_fixture_and_run() {
    fixturename=$1

    # Set up.
    git_apply_fixture verify_commit_messages/$1
    export initialcommit=$FIXTURE_HASH_BEFORE
    export finalcommit=$FIXTURE_HASH_AFTER
    export shorthash=$(cd $gitdir && git rev-list -n1 --abbrev-commit $finalcommit)

    ci_run verify_commit_messages/verify_commit_messages.sh
}

@test "verify_commit_messages/verify_commit_messages.sh: invalid options" {
    ci_run verify_commit_messages/verify_commit_messages.sh
    assert_failure
    assert_output "Error: initialcommit environment variable is not defined. See the script comments."

    export initialcommit="foo"

    ci_run verify_commit_messages/verify_commit_messages.sh
    assert_failure
    assert_output "Error: finalcommit environment variable is not defined. See the script comments."

    export finalcommit="bar"
    ci_run verify_commit_messages/verify_commit_messages.sh
    assert_failure
    assert_output "Error: initial commit does not exist (foo)"
}

@test "verify_commit_messages/verify_commit_messages.sh: good commit" {
    commit_apply_fixture_and_run ok.patch
    assert_success
    assert_output ""
}

@test "verify_commit_messages/verify_commit_messages.sh: long first line " {
    commit_apply_fixture_and_run too-long.patch
    assert_failure
    assert_output "${shorthash}*error*The first line has more than 72 characters (found: 86)"
}

@test "verify_commit_messages/verify_commit_messages.sh: no MDL" {
    commit_apply_fixture_and_run no-issue-id.patch
    assert_failure
    assert_line --index 0 "${shorthash}*error*The commit message does not begin with the expected issue code MDL-[0-9]{3,6} and a space."
    assert_line --index 1 "${shorthash}*error*The commit message does not contain the expected issue code MDL-12345 and a space."
}

@test "verify_commit_messages/verify_commit_messages.sh: no MDL when issue unknown" {
    export issuecode=""

    commit_apply_fixture_and_run no-issue-id.patch
    assert_failure
    assert_output "${shorthash}*error*The commit message does not begin with the expected issue code MDL-[0-9]{3,6} and a space."
}

@test "verify_commit_messages/verify_commit_messages.sh: no colon" {
    commit_apply_fixture_and_run no-colon.patch
    assert_failure
    assert_output "${shorthash}*warning*The commit message contains MDL-12345 followed by a colon. The expected format is 'MDL-12345 codearea: message'"
}

@test "verify_commit_messages/verify_commit_messages.sh: no code area" {
    commit_apply_fixture_and_run no-code-area.patch
    assert_failure
    assert_output "${shorthash}*warning*The commit message does not define a code area ending with a colon and a space after the issue code."
}

@test "verify_commit_messages/verify_commit_messages.sh: body too long" {
    commit_apply_fixture_and_run too-long-body.patch
    assert_failure
    assert_output "${shorthash}*error*The line #3 has more than 132 characters (found: 181)"
}
