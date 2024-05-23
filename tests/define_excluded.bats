#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.0
}

# Helper for repetitive excluded asserions on all the formats
# usage: assert_define_excluded format
assert_define_excluded_format () {
    export format=$1
    expected=$BATS_TEST_DIRNAME/fixtures/define_excluded/format-$format-expected.txt

    ci_run define_excluded/define_excluded.sh
    assert_success
    # Don't want full paths ever
    refute_output --partial "$(dirname $gitdir)"

    # Verify all expectations in fixture are in results.
    while read -r expectation; do
        [[ "$expectation" =~ ^#.*$ ]] && continue # Skip comments.
        assert_output --partial "$expectation"
    done < "$expected"
}

@test "define_excluded: generates results correctly for all formats" {
    formats=('excluded' 'excluded_comma' 'excluded_comma_wildchars' \
             'excluded_grep' 'excluded_list' 'excluded_list_wildchars')
    for format in "${formats[@]}"; do
        assert_define_excluded_format $format
    done
}

@test "define_excluded: is immune to trailing slashes in gitdir" {
    export gitdir=$gitdir////
    assert_define_excluded_format excluded
}
