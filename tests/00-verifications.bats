#!/usr/bin/env bats

load libs/shared_setup

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
    nonexecutables=('bash' 'html' 'jar' 'md' 'out' 'patch' 'php' 'template' 'txt' 'xml' 'xsl' 'yml')
    # Other nonexecutable files, but looked by name, not by extension
    otherfiles=('.gitignore' '.htaccess')

    # git does NOT track directory perms at all, so we comment aout this test. Just kept here for reference.
    # Directories must have execution bits set
    # run find $BATS_TEST_DIRNAME/.. -type d -not -perm -u+x,g+x,a+x -not -path "*/.git/*"
    # assert_success
    # assert_output ""

    # Executables must have execution bits set
    for executable in "${executables[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "*.${executable}" -type f -not -perm -u+x,g+x,a+x -not -path "*/.git/*"
        assert_success
        assert_output ""
    done

    # Non executables must not have execution bits set
    for nonexecutable in "${nonexecutables[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "*.${nonexecutable}" -type f -perm -u+x,g+x,a+x -not -path "*/.git/*"
        assert_success
        assert_output ""
    done

    # Other files must not have execution bits set
    for otherfile in "${otherfiles[@]}"; do
        run find $BATS_TEST_DIRNAME/.. -name "${otherfile}" -type f -perm -u+x,g+x,a+x -not -path "*/.git/*"
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
        -not -path "*/.git/*"
    assert_success
    assert_output ""
}

