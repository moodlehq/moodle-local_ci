#!/usr/bin/env bats

load libs/shared_setup

setup () {
    cd $BATS_TEST_DIRNAME/../
}

# Helper to assert diff_extract_changes output
# usage: pssert_diff_extract_changes format fixturefilename expectedfilename
assert_diff_extract_changes() {
    format=$1
    fixture=$BATS_TEST_DIRNAME/fixtures/$2
    expected=$BATS_TEST_DIRNAME/fixtures/$3

    out=$BATS_TMPDIR/diff_extract_changes-out

    php diff_extract_changes/diff_extract_changes.php --diff=$fixture --output=$format > $out
    assert_success
    diff -ruN $expected $out
    assert_output ''
    rm $out
}

@test "diff_extract_changes: xml" {
    assert_diff_extract_changes xml diff_extract_changes-input.patch diff_extract_changes-expected.xml
}

@test "diff_extract_changes: txt" {
    assert_diff_extract_changes txt diff_extract_changes-input.patch diff_extract_changes-expected.txt
}
