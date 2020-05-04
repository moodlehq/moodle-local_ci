#!/usr/bin/env bats

load libs/shared_setup

setup () {
    create_git_branch master origin/master
    rm -fr $gitdir/node_modules
    rm -fr $gitdir/npm-shrinkwrap.json
}

@test "prepare_npm_stuff: Verify that .nvm existence is checked" {

    ci_run prepare_npm_stuff/prepare_npm_stuff.sh

    # Assert result.
    assert_success
    assert_output --partial "INFO: .nvmrc file found: $(<$gitdir/.nvmrc). Installing node..."
    assert_output --partial "INFO: nvm version:"
    assert_output --partial "INFO: node installation completed"
    assert_output --partial "INFO: node version:"
    assert_output --partial "INFO: npm version:"
    assert_output --partial "INFO: Installing npm stuff following package/shrinkwrap details"
    assert_output --partial "INFO:    - Installed grunt"
}

@test "prepare_npm_stuff: No HOME/.nvm installs via git" {
    # Set up.
    rm -fr $HOME/.nvm

    ci_run prepare_npm_stuff/prepare_npm_stuff.sh

    # Assert result.
    assert_success
    assert_output --partial "INFO: nvm not found, installing via git"
    assert_output --partial "INFO: nvm git installation found, updating to latest release"
    assert_output --partial "INFO: using nvm version:"
    assert_output --partial "INFO: .nvmrc file found: $(<$gitdir/.nvmrc). Installing node..."
    assert_output --partial "INFO: Installing npm stuff following package/shrinkwrap details"
    assert_output --partial "INFO:    - Installed grunt"
}

@test "prepare_npm_stuff: No .nvmrc so we won't run any nvm command" {
    # Set up.
    rm -fr $gitdir/.nvmrc

    ci_run prepare_npm_stuff/prepare_npm_stuff.sh

    # Assert result.
    # Cannot know if install will success or no (depends if npm/node binaries are elsewhere)
    # (hence, we are not asserting the result, just that the case is handled)
    assert_output --partial "INFO: using nvm version:"
    assert_output --partial "INFO: .nvmrc not found, nvm install skipped"
    assert_output --partial "INFO: Installing npm stuff following package/shrinkwrap details"
}

@test "prepare_npm_stuff: No HOME/.nvm neither .nvmrc is allowed" {
    # Set up.
    rm -fr $HOME/.nvm
    rm -fr $gitdir/.nvmrc

    ci_run prepare_npm_stuff/prepare_npm_stuff.sh

    # Assert result.
    # Cannot know if install will success or no (depends if npm/node binaries are elsewhere)
    # (hence, we are not asserting the result, just that the case is handled)
    assert_output --partial "INFO: nvm not found, installing via git"
    assert_output --partial "INFO: nvm git installation found, updating to latest release"
    assert_output --partial "INFO: using nvm version:"
    assert_output --partial "INFO: .nvmrc not found, nvm install skipped"
    assert_output --partial "INFO: Installing npm stuff following package/shrinkwrap details"
}

@test "prepare_npm_stuff: Install custom node v10.18.1 works ok" {
    # Set up.
    echo "v10.18.1" > $gitdir/.nvmrc

    ci_run prepare_npm_stuff/prepare_npm_stuff.sh

    # Assert result.
    assert_success
    assert_output --partial "INFO: using nvm version:"
    assert_output --partial "INFO: .nvmrc file found: v10.18.1. Installing node.."
    assert_output --partial "INFO: node installation completed"
    assert_output --partial "INFO: node version: v10.18.1"
    assert_output --partial "INFO: npm version: 6.13.4"
    assert_output --partial "INFO: Installing npm stuff following package/shrinkwrap details"
    assert_output --partial "INFO:    - Installed grunt"
}
