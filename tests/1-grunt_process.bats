#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch MOODLE_39_STABLE v3.9.0

    export npminstall=1
}

@test "grunt_process: normal" {
    ci_run grunt_process/grunt_process.sh
    assert_success
    assert_output --partial "Done."
    assert_output --partial "OK: All modules are perfectly processed by grunt"
}

@test "grunt_process: Uncommited .scss change" {
    # Create scss change
    git_apply_fixture 39-grunt-scss-unbuilt.patch

    # Run test
    ci_run grunt_process/grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "Done." # Grunt shouldn't have an issue here.
    assert_output --partial "WARN: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/theme/boost/style/moodle.css"
}

@test "grunt_process: Uncommited .js change" {
    # Create js change.
    git_apply_fixture 39-grunt-js-unbuilt.patch

    # Run test
    ci_run grunt_process/grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "Done." # Grunt shouldn't have an issue here.
    assert_output --partial "WARN: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/lib/amd/build/url.min.js"
}

@test "grunt_process: Uncommited ignorefiles change" {
    # When a third party library is added, developers need to commit
    # ignorefiles change since 3.2.

    # Testing on v3.5.9
    create_git_branch 35-stable v3.5.9
    git_apply_fixture 35-thirdparty-lib-added.patch

    # Run test
    ci_run grunt_process/grunt_process.sh

    # Assert result
    assert_failure
    assert_output --partial "WARN: Some modules are not properly processed by grunt. Changes detected:"
    assert_output --regexp "GRUNT-CHANGE: (.*)/.eslintignore"
}

@test "grunt_process: Uncommited ignorefiles ignored when checking plugin" {
    # When a 3rd party library is added, but we are checking a 3rd part plugin
    # we ignore any change in ignorefiles.

    # Testing on v3.5.9
    create_git_branch 35-stable v3.5.9
    git_apply_fixture 35-thirdparty-lib-added.patch

    # Run test
    export isplugin=1
    ci_run grunt_process/grunt_process.sh

    # Assert result
    assert_success
    assert_output --partial "Running \"ignorefiles\" task"
    assert_output --partial "Looking for changes, applying some exclusion with"
    assert_output --partial " -e .eslintignore "
    assert_output --partial "OK: All modules are perfectly processed by grunt"
}

@test "grunt process: Problems generating jsdoc" {
    # When something in the jsdoc annotations is incorrect and leads the grunt jsdoc task to fail

    # Testing on 4.2.0 because there was an error there, fixed few weeks later by MDL-78323. So we don't need any fixture.
    create_git_branch 402-stable v4.2.0

    # Run test
    ci_run grunt_process/grunt_process.sh

    assert_failure
    assert_output --partial "Running \"jsdoc:dist\" (jsdoc) task"
    assert_output --partial "ERROR: Unable to parse a tag's type expression for source file"
    assert_output --partial "grade/report/grader/amd/src/collapse.js in line 497"
}
