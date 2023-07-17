#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.2
}

@test "mustache_lint: Good mustache file" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting_ok.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: No example content" {
    # Set up.
    git_apply_fixture 31-mustache_lint-no-example.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting.mustache - WARNING: Example context missing."
    assert_output --partial "Mustache lint problems found"
}

@test "mustache_lint: Example content invalid json" {
    # Set up.
    git_apply_fixture 31-mustache_lint-invalid-json.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting.mustache - ERROR: Mustache syntax exception: Example context JSON is unparsable, fails with: Syntax error"
    assert_output --partial "Mustache lint problems found"
}

@test "mustache_lint: Mustache syntax error" {
    # Set up.
    git_apply_fixture 31-mustache_lint-mustache-syntax-error.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting.mustache - ERROR: Mustache syntax exception: Missing closing tag: test opened on line 2"
    assert_output --partial "Mustache lint problems found"
}

@test "mustache_lint: HTML validation issue" {
    # Set up.
    git_apply_fixture 31-mustache_lint-html-validator-fail.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "NPM installed validator found."
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting.mustache - WARNING: HTML Validation error, line 2: End tag “p” seen, but there were open elements. (ello World</p></bo)"
    assert_output --partial "lib/templates/linting.mustache - WARNING: HTML Validation error, line 2: Unclosed element “span”. (<body><p><span>Hello )"
    assert_output --partial "Mustache lint problems found"
}

@test "mustache_lint: Partials are loaded" {
    # Set up.
    git_apply_fixture 31-mustache_lint-partials-loaded.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    # If the partial was not loaded we'd produce this info message:
    refute_output --partial "test_partial_loading.mustache - INFO: Template produced no content"

    assert_output --partial "blocks/lp/templates/test_partial_loading.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Full HTML page doesn't get embeded in <html> body" {
    # Set up.
    git_apply_fixture 31-mustache_lint-full-html-body.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    # We should not have a vlidation warning about multiple 'html' tags.
    refute_output --partial 'Stray start tag “html”.'

    assert_output --partial "lib/templates/full-html-page.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Theme templates load theme partials" {
    # Set up.
    git_apply_fixture 31-mustache_lint-theme_loading.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert that test-theme-loading.mustache validates succesfully.
    assert_output --partial "theme/bootstrapbase/templates/test-theme-loading.mustache - OK: Mustache rendered html succesfully"

    # But note that this run will fail because of an invalid partial (div-start.mustache) - MDL-56504
    assert_failure
}

@test "mustache lint: Test str helper is working" {
    # Set up.
    create_git_branch MOODLE_402_STABLE v4.2.0
    git_apply_fixture 402-mustache_lint-str.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "lib/templates/test_str.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Test quote and uniq helpers are working" {
    # Set up.
    git_apply_fixture 31-mustache_lint-quote_and_uniq.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "lib/templates/test_uniq_and_quote.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Test eslint doesn't run when not present" {

    # Setup. We are on v3.1.1, which doesn't have eslint in package.json (or npm installed here)
    git_apply_fixture 31-mustache_lint-js_test.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "lib/templates/js_test.mustache - INFO: ESLint did not run"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Test eslint runs when npm installed" {

    # a8c64d6 has eslint in package.json (switch to v3.1.3 when releaseD)
    create_git_branch MOODLE_31_STABLE a8c64d6267fd0a2f12435ea75af88eb4de980d6f
    git_apply_fixture 31-mustache_lint-js_test.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Install npm depends so we have eslint
    ci_run prepare_npm_stuff/prepare_npm_stuff.sh
    # Run with eslint.
    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "lib/templates/js_test.mustache - WARNING: ESLint warning [camelcase]: Identifier 'my_message' is not in camel case"
    assert_output --partial "lib/templates/js_test.mustache - WARNING:     var my_message = 'Hello World!';"
    assert_output --partial "lib/templates/js_test.mustache - WARNING:         ^"
    assert_output --partial "lib/templates/js_test.mustache - WARNING: ESLint warning [no-alert]: Unexpected alert."
    assert_output --partial "lib/templates/js_test.mustache - WARNING:     alert(my_message);"
    assert_output --partial "lib/templates/js_test.mustache - WARNING:     ^"
}

@test "mustache_lint: Test eslint handles parsing failures safely" {

    # a8c64d6 has eslint in package.json (switch to v3.1.3 when releaseD)
    create_git_branch MOODLE_31_STABLE a8c64d6267fd0a2f12435ea75af88eb4de980d6f
    git_apply_fixture 31-mustache_lint-js_token_test.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Install npm depends so we have eslint
    ci_run prepare_npm_stuff/prepare_npm_stuff.sh
    # Run with eslint.
    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "lib/templates/js_token_test.mustache - INFO: ESLint reported JavaScript errors"
    assert_output --partial "lib/templates/js_token_test.mustache - WARNING: ESLint error []: Parsing error: Unexpected token bar, Line: 2 Column: 13"
    assert_output --partial "lib/templates/js_token_test.mustache - WARNING:     var foo bar baz = 'bum';"
    assert_output --partial "lib/templates/js_token_test.mustache - WARNING:             ^"
}

@test "mustache_lint: Test eslint runs ok when invoked from any directory" {

    # We need to use recent version here, the default 3.1.3 used for tests (that already had eslint)
    # did not expose the problem (and it ran ok from any CWD directory).
    # TODO: Some day, kill all old-version tests by moving them to 39_STABLE or later.
    create_git_branch MOODLE_39_STABLE v3.9.2

    # Calculate moodleroot and localciroot.
    localciroot=$PWD
    moodleroot=${LOCAL_CI_TESTS_GITDIR}

    # Install npm depends so we have eslint (sourced).
    source ${localciroot}/prepare_npm_stuff/prepare_npm_stuff.sh

    # Run normally (from moodleroot).
    cd ${moodleroot}
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/lib/templates/inplace_editable.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"
    assert_success
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"

    # Run also from another dir within moodleroot.
    cd ${moodleroot}/mod/forum
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/lib/templates/inplace_editable.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"
    assert_success
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"

    # Let's switch to any other directory (out from moodleroot).
    cd ${moodleroot}/..
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/lib/templates/inplace_editable.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"
    assert_success
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"
    refute_output --partial "${LOCAL_CI_TESTS_CACHEDIR}"
}
