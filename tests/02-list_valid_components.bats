#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0
}

@test "list_valid_components: 31 components" {
    # We need to rewrite the directory in the fixture for verifying correct result.
    EXPECTED=$WORKSPACE/valid_components_expected.txt
    sed -e "s#\[gitdir\]#${gitdir}#" $BATS_TEST_DIRNAME/fixtures/31-valid_components.txt > $EXPECTED

    OUTPUT=$WORKSPACE/valid_components_out.txt

    # Run test
    ci_run_php "list_valid_components/list_valid_components.php --basedir=$gitdir > $OUTPUT"
    assert_success
    diff -ruN $EXPECTED $OUTPUT
    assert_output ''

    rm $EXPECTED $OUTPUT
}

