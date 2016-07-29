#!/usr/bin/env bats

load libs/shared_setup

# This test is just used to verify there aren't /bin/bash uses in the shell scripts
# (we should be using env bash for portability)
@test "code_checks: bin/bash is nor being used anywhere" {
    run grep -r '^#!.*bin/bash' $BATS_TEST_DIRNAME/..
    assert_output ""
}
