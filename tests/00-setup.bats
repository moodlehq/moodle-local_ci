#!/usr/bin/env bats

load libs/shared_setup

# This test is just used as some quick output because some tests are v.slow
@test "Git is setup for tests." {
    [ -d "$gitdir/.git" ];
    assert_success
}

@test "GNU grep installed" {
    # Some scripts depend on grep -P
    echo 'test2' | grep -P '^(test\d|testing)$'
    assert_success
}

@test "GNU sed installed" {
    # Some scripts depend on sed -r
    echo 'test1' | sed -r 's/^test[0-9]$/replaced/'
    assert_success
}
