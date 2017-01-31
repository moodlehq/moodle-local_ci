#!/usr/bin/env bats

load libs/shared_setup

@test "first_test(): first reported correctly" {
    run first_test
    assert_success
}

@test "first_test(): !first reported correctly" {
    run first_test
    assert_failure
}

# This test is just used to verify there aren't #!/bin/bash uses in the shell scripts
# (we should be using env bash for portability)
@test "#!/bin/bash is not being used in code base" {
    run grep -r '^#!.*bin/bash' $BATS_TEST_DIRNAME/..
    assert_output ""
}

# This test verifies permissions of directories and important files are correct.
@test "repository file & dir permissions are correct" {
    # Define executable and non-executable extensions
    executables=('sh' 'bats')
    nonexecutables=('bash' 'html' 'jar' 'md' 'out' 'patch' 'php' 'template' 'txt' 'xml' 'xsl' 'yml' 'groovy')
    # Other nonexecutable files, but looked by name, not by extension
    otherfiles=('.gitignore' '.htaccess')

    # git does NOT track directory perms at all, so we comment aout this test. Just kept here for reference.
    # Directories must have execution bits set
    # run find $BATS_TEST_DIRNAME/.. -type d -not -perm -u+x,g+x,a+x -not -path "*/.git/*"
    # assert_success
    # assert_output ""

    # Executables must have execution bits set
    for executable in "${executables[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "*.${executable}" -type f -not -perm -u+x,g+x,a+x \
            -not -path "*/.git/*" \
            -not -path "*/vendor/*" \
            -not -path "*/composer.*"
        assert_success
        assert_output ""
    done

    # Non executables must not have execution bits set
    for nonexecutable in "${nonexecutables[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "*.${nonexecutable}" -type f -perm -u+x,g+x,a+x \
            -not -path "*/.git/*" \
            -not -path "*/vendor/*" \
            -not -path "*/composer.*"
        assert_success
        assert_output ""
    done

    # Other files must not have execution bits set
    for otherfile in "${otherfiles[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "${otherfile}" -type f -perm -u+x,g+x,a+x \
            -not -path "*/.git/*" \
            -not -path "*/vendor/*" \
            -not -path "*/composer.*"
        assert_success
        assert_output ""
    done

    # Verify we have covered all files
    searchexpression=''
    # Buld the search of the extensions covered
    for extension in "${executables[@]}" "${nonexecutables[@]}"; do
        searchexpression="${searchexpression}|\.${extension}"
    done
    # Build the search of the names covered
    for otherfile in "${otherfiles[@]}"; do
        searchexpression="${searchexpression}|${otherfile}"
    done
    searchexpression=${searchexpression#"|"}
    run find $BATS_TEST_DIRNAME/.. \
        -type f -regextype posix-extended \
        -not -regex ".*(${searchexpression})" \
        -not -path "*/.git/*" \
        -not -path "*/vendor/*" \
        -not -path "*/composer.*"
    assert_success
    assert_output ""
}

@test "clean_workspace_directory() cleans all files" {
    touch $WORKSPACE/foo
    touch $WORKSPACE/.bar
    mkdir $WORKSPACE/subdirectory
    touch $WORKSPACE/subdirectory/foo
    touch $WORKSPACE/subdirectory/.bar

    run find $WORKSPACE -type f
    assert_success
    refute_output "" # there should be files here..

    clean_workspace_directory

    run find $WORKSPACE -type f
    assert_output ""
}

@test "workspace cleaned between runs: setup" {
    touch $WORKSPACE/workspace-dirty-$PPID
    run [ -f $WORKSPACE/workspace-dirty-$PPID ]
    assert_success
}

@test "workspace cleaned between runs: verify" {
    run [ -f $WORKSPACE/workspace-dirty-$PPID ]
    assert_failure
}

@test "store_workspace()" {
    echo "Created by process: $PPID" > $WORKSPACE/storedfile
    run [ -f $WORKSPACE/storedfile ]
    assert_success
    run store_workspace
    assert_success
}

@test "restore_workspace()" {
    run [ -f $WORKSPACE/storedfile ]
    assert_failure

    run restore_workspace
    assert_success
    run [ -f $WORKSPACE/storedfile ]
    assert_success
    run cat $WORKSPACE/storedfile
    assert_output "Created by process: $PPID"
}

@test "assert_files_same(): empty file validations" {
    touch $WORKSPACE/expected
    touch $WORKSPACE/actual

    # Should fail to operate on empty files
    run assert_files_same $WORKSPACE/expected $WORKSPACE/actual
    assert_failure
    assert_output "$WORKSPACE/expected is empty"

    # Should fail because actual still empty.
    echo 'no longer empty' > $WORKSPACE/expected
    run assert_files_same $WORKSPACE/expected $WORKSPACE/actual
    assert_failure
    assert_output "$WORKSPACE/actual is empty"

    # Now we pass as files are the same
    cp $WORKSPACE/expected $WORKSPACE/actual
    run assert_files_same $WORKSPACE/expected $WORKSPACE/actual
    assert_success
}

@test "assert_files_same(): detects differences" {
    echo "123" > $WORKSPACE/expected
    echo "456" > $WORKSPACE/actual

    # Should fail as there are differences
    run assert_files_same $WORKSPACE/expected $WORKSPACE/actual
    assert_failure

    # Make files the same
    cp $WORKSPACE/expected $WORKSPACE/actual
    # Now should pass..
    run assert_files_same $WORKSPACE/expected $WORKSPACE/actual
    assert_success
}

@test "last_test(): !last reported correctly" {
    run last_test
    assert_failure
}

# Leave this test last in file!
@test "last_test(): final test reported correctly" {
    run last_test
    assert_success
}
