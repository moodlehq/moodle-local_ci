#!/usr/bin/env bats

load libs/shared_setup

@test "Git is setup for tests." {
    [ -d "$gitdir/.git" ];
    assert_success
}

@test "phpcs standard path is properly set" {
    run [ -f "$LOCAL_CI_TESTS_PHPCS_DIR/ruleset.xml" ];
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

@test "GNU wc installed" {
    # Some scripts depend on wc -l having no padding..
    run bash -c "echo '1' | wc -l"
    assert_success
    assert_output '1'
}

@test "GNU date installed" {
    # Some scripts depend on date -I for iso date
    run date -I
    assert_success
}
