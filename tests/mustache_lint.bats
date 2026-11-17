#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_31_STABLE v3.1.2
}

# Track things we temporarily move aside during a test, so teardown() can restore them.
CACHED_JAVA_HIDDEN=0
VNUJAR_HIDDEN=0

# Hide the JRE auto-installed by the vnu-jar npm package (node_modules/.cache/vnu-jar/java),
# so tests can exercise the system-java and java-less paths.
hide_cached_java() {
    cachedjava="$PWD/node_modules/.cache/vnu-jar/java"
    if [ -d "$cachedjava" ]; then
        mv "$cachedjava" "${cachedjava}.hidden"
        CACHED_JAVA_HIDDEN=1
    fi
}

restore_cached_java() {
    if [ "${CACHED_JAVA_HIDDEN}" = "1" ]; then
        # Drop whatever a test left at the destination (e.g. a simulated JRE).
        rm -rf "$PWD/node_modules/.cache/vnu-jar/java" 2>/dev/null || true
        mv "$PWD/node_modules/.cache/vnu-jar/java.hidden" "$PWD/node_modules/.cache/vnu-jar/java" 2>/dev/null || true
        CACHED_JAVA_HIDDEN=0
    fi
}

teardown() {
    restore_cached_java
    if [ "${VNUJAR_HIDDEN}" = "1" ]; then
        mv "$PWD/node_modules/vnu-jar.hidden" "$PWD/node_modules/vnu-jar" 2>/dev/null || true
        VNUJAR_HIDDEN=0
    fi
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

@test "mustache_lint: Dialog closedby attribute is accepted" {
    # Set up.
    git_apply_fixture 31-mustache_lint-dialog-closedby.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    # Assert result. The dialog "closedby" attribute (HTML spec, late 2025) is only
    # accepted by vnu-jar 25.12.5+; keep this test as a regression guard for the pin.
    assert_success
    assert_output --partial "Running mustache lint from $GIT_PREVIOUS_COMMIT to $GIT_COMMIT"
    assert_output --partial "lib/templates/linting_dialog_closedby.mustache - OK: Mustache rendered html succesfully"
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

@test "mustache_lint: Fails with guidance when Java is missing" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Hide any JRE auto-installed by the vnu-jar npm package.
    hide_cached_java

    # Simulate a system without java: prepend a failing java stub to PATH.
    fakebindir=$(mktemp -d)
    cat > "$fakebindir/java" <<'EOF'
#!/bin/sh
# Simulate "java: command not found".
exit 127
EOF
    chmod +x "$fakebindir/java"

    PATH="$fakebindir:$PATH" ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "NPM installed validator available, but java not found in path."
    assert_output --partial "Please install Java 17 or above"
    assert_output --partial "the self-contained vnu binary"
}

@test "mustache_lint: Fails with guidance when Java is too old" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Hide any JRE auto-installed by the vnu-jar npm package.
    hide_cached_java

    # Simulate an old java (1.8) reporting its version.
    fakebindir=$(mktemp -d)
    cat > "$fakebindir/java" <<'EOF'
#!/bin/sh
echo 'java version "1.8.0_412"' >&2
exit 0
EOF
    chmod +x "$fakebindir/java"

    PATH="$fakebindir:$PATH" ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "NPM installed validator available, but java version too low: 1.8"
    assert_output --partial "Please install Java 17 or above"
}

@test "mustache_lint: Uses the JRE auto-installed by the vnu-jar npm package when Java is missing" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Need a real java to delegate to; skip if none is available (command -v fails
    # under bats' set -e, so guard it).
    realjava=$(command -v java || true)
    if [ -z "$realjava" ]; then
        return 0
    fi

    # Hide any JRE auto-installed by the vnu-jar npm package.
    hide_cached_java

    # Simulate the JRE auto-installed by the vnu-jar npm package postinstall,
    # delegating to the real system java.
    cachedjava="$PWD/node_modules/.cache/vnu-jar/java"
    cachedbin="$cachedjava/jdk-17.0.17+10-jre/bin"
    mkdir -p "$cachedbin"
    cat > "$cachedbin/java" <<EOF
#!/bin/sh
exec "$realjava" "\$@"
EOF
    chmod +x "$cachedbin/java"

    # Simulate a system without java.
    fakebindir=$(mktemp -d)
    cat > "$fakebindir/java" <<'EOF'
#!/bin/sh
exit 127
EOF
    chmod +x "$fakebindir/java"

    PATH="$fakebindir:$PATH" ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_success
    assert_output --partial "NPM installed validator found."
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: PHP script fails with guidance when Java is missing" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    localciroot=$PWD
    moodleroot=${LOCAL_CI_TESTS_GITDIR}

    # Hide any JRE auto-installed by the vnu-jar npm package.
    hide_cached_java

    # Simulate a system without java.
    fakebindir=$(mktemp -d)
    cat > "$fakebindir/java" <<'EOF'
#!/bin/sh
exit 127
EOF
    chmod +x "$fakebindir/java"

    # Run the PHP script directly (as moodle-plugin-ci does), with the jar
    # passed explicitly and no java available.
    PATH="$fakebindir:$PATH" ci_run_php mustache_lint/mustache_lint.php \
        --filename="${moodleroot}/lib/templates/linting_ok.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"

    # Assert result
    assert_failure
    assert_output --partial "The vnu.jar HTML validator requires Java 17 or above, but no Java runtime was found."
    assert_output --partial "Please install Java 17 or above"
}

@test "mustache_lint: Fails with guidance when no validator is available" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # Hide the NPM-installed validator to simulate a checkout without npm install.
    vnujar="$PWD/node_modules/vnu-jar"
    if [ -d "$vnujar" ]; then
        mv "$vnujar" "${vnujar}.hidden"
        VNUJAR_HIDDEN=1
    fi

    ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "No NPM-installed validator found (node_modules/vnu-jar is missing) and no validator was configured."
}

@test "mustache_lint: Explicit validator URL is respected over the NPM jar" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    # An explicitly configured validator must always win over the NPM-installed jar,
    # even when the jar is present and java resolves. Nothing listens on port 8888,
    # so validation itself fails; the point is the selection, not the outcome.
    validator="http://localhost:8888/" ci_run mustache_lint/mustache_lint.sh

    # Assert result
    assert_failure
    assert_output --partial "Validating using http://localhost:8888/"
    refute_output --partial "NPM installed validator found."
}

@test "mustache_lint: PHP script distinguishes a too-old Java from no Java" {
    # Set up.
    git_apply_fixture 31-mustache_lint-ok.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    localciroot=$PWD
    moodleroot=${LOCAL_CI_TESTS_GITDIR}

    # Hide any JRE auto-installed by the vnu-jar npm package.
    hide_cached_java

    # Simulate an old java (11) reporting its version.
    fakebindir=$(mktemp -d)
    cat > "$fakebindir/java" <<'EOF'
#!/bin/sh
echo 'java version "11.0.32"' >&2
exit 0
EOF
    chmod +x "$fakebindir/java"

    PATH="$fakebindir:$PATH" ci_run_php mustache_lint/mustache_lint.php \
        --filename="${moodleroot}/lib/templates/linting_ok.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"

    # Assert result
    assert_failure
    assert_output --partial "The vnu.jar HTML validator requires Java 17 or above, but found Java 11.0.32."
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

@test "mustache_lint: Test userdate renders dates in attributes and headings" {
    git_apply_fixture 31-mustache_lint-userdate.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    assert_success
    assert_output --partial "lib/templates/test_userdate.mustache - OK: Mustache rendered html succesfully"
    refute_output --partial "Empty heading"
}

@test "mustache_lint: Test htmldatetime renders timestamps and preserves overrides" {
    git_apply_fixture 31-mustache_lint-htmldatetime.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    assert_success
    assert_output --partial "lib/templates/test_htmldatetime.mustache - OK: Mustache rendered html succesfully"
    assert_output --partial "No mustache problems found"
}

@test "mustache_lint: Test htmldatetime exposes invalid overrides to validation" {
    git_apply_fixture 31-mustache_lint-htmldatetime-invalid.patch
    export GIT_PREVIOUS_COMMIT=$FIXTURE_HASH_BEFORE
    export GIT_COMMIT=$FIXTURE_HASH_AFTER

    ci_run mustache_lint/mustache_lint.sh

    assert_failure
    assert_output --partial 'Bad value “2/1/1933” for attribute “datetime”'
    assert_output --partial 'Bad value “0” for attribute “datetime”'
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
    assert_output --partial "INFO: ESLint did not run"
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
    assert_output --partial "INFO: ESLint did run"
    assert_output --partial "lib/templates/js_test.mustache - WARNING: ESLint warning [camelcase]: Identifier 'my_message' is not in camel case"
    assert_output --partial "lib/templates/js_test.mustache - WARNING: ESLint warning [no-alert]: Unexpected alert. ( alert(my_message); )"
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
    assert_output --partial "INFO: ESLint did run"
    assert_output --partial "lib/templates/js_token_test.mustache - WARNING: ESLint error []: Parsing error: Unexpected token bar ( var foo bar baz = 'bum'; )"
}

@test "mustache lint: Test eslint is immune to the {{#js}}...{{#js}} position in templates" {
    create_git_branch MOODLE_403_STABLE v4.3.0

    # Calculate moodleroot and localciroot.
    localciroot=$PWD
    moodleroot=${LOCAL_CI_TESTS_GITDIR}

    # Note, we don't have to apply any fixture because there are real cases in core
    # which are using {{#js}}...{{/js}} with non-trimmed whitespace around them. So
    # just let's use one of them to verify that out js helper workarounds the problem.

    # Install npm depends so we have eslint (sourced).
    source ${localciroot}/prepare_npm_stuff/prepare_npm_stuff.sh

    # Run normally (from moodleroot).
    cd ${moodleroot}
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/mod/data/templates/action_bar.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"

    # Assert result.
    assert_success
    assert_output --partial "INFO: ESLint did run"
    refute_output --partial "ESLint error [no-trailing-spaces]"
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
    assert_output --partial "INFO: ESLint did run"
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"

    # Run also from another dir within moodleroot.
    cd ${moodleroot}/mod/forum
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/lib/templates/inplace_editable.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"
    assert_success
    assert_output --partial "INFO: ESLint did run"
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"

    # Let's switch to any other directory (out from moodleroot).
    cd ${moodleroot}/..
    ci_run_php mustache_lint/mustache_lint.php --filename="${moodleroot}/lib/templates/inplace_editable.mustache" \
        --basename="${moodleroot}" --validator="${localciroot}/node_modules/vnu-jar/build/dist/vnu.jar"
    assert_success
    assert_output --partial "INFO: ESLint did run"
    refute_output --partial "INFO: ESLint did not run"
    refute_output --partial "was not found when loaded as a Node module"
    refute_output --partial "${LOCAL_CI_TESTS_CACHEDIR}"
}
