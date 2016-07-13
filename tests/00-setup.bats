#!/usr/bin/env bats

load libs/shared_setup

# This test is just used as some quick output because some tests are v.slow
@test "Git is setup for tests." {
    [ -d "$gitdir/.git" ];
    assert_success
}
