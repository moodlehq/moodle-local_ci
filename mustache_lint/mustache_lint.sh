#!/usr/bin/env bash
# $gitcmd: Path to the git CLI executable
# $gitdir: Directory containing git repo
# $phpcmd: Path to php CLI exectuable
# $validator: (optional) validator URL or path to the vnu.jar. When unset, the
# NPM-installed vnu.jar is used if present (requires Java 17+); otherwise the
# script fails with guidance instead of silently using the public validator.
#
# Based on GIT_PREVIOUS_COMMIT and GIT_COMMIT will list all changed php
# files and run lint on them.
#
# When the NPM-installed validator is used, a Java 17+ runtime is required
# (system java first, then the JRE auto-installed by the vnu-jar npm package
# during npm install). If none is found the script fails with guidance.
#
set -e

# Verify everything is set
required="gitcmd gitdir phpcmd GIT_PREVIOUS_COMMIT GIT_COMMIT"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Print a Java-missing/too-old error and exit.
# $1: reason why the NPM-installed validator cannot be used.
validator_java_error() {
    echo "NPM installed validator available, but $1"
    echo "Please install Java 17 or above (e.g. apt install openjdk-17-jre or brew install openjdk@17), or use one of the alternatives:"
    echo "  - the self-contained vnu binary (https://validator.github.io/validator/)"
    echo "  - a validator service, passed via the \$validator variable (e.g. validator=http://localhost:8888/)"
    exit 1
}

# Locate a Java 17+ runtime to run the NPM-installed vnu.jar:
# 1. java available on the PATH.
# 2. JRE auto-installed by the vnu-jar npm package during npm install
#    (node_modules/.cache/vnu-jar/java/).
# Sets $VALIDATOR_JAVA_CMD to the executable path on success and returns 0.
# On failure returns 1 and leaves $VALIDATOR_JAVA_CMD empty.
find_validator_java() {
    VALIDATOR_JAVA_CMD=""
    if java -version 2>&1 >/dev/null | grep -Eq "(java|openjdk) version"
    then
        # Extract major and minor digits of version and compare it as float
        # numbers. Not error proof, but sufficient to ensure it is >= 17
        # (vnu.jar 26.x requires Java 17 or above).
        validator_java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | sed 's/^\([0-9]*\.[0-9]*\).*$/\1/')
        if [ $( echo "${validator_java_version} >= 17" | bc ) == 1 ]
        then
            VALIDATOR_JAVA_CMD="java"
            return 0
        fi
    fi

    # The vnu-jar npm package auto-installs a JRE during postinstall when no
    # system java is found: node_modules/.cache/vnu-jar/java/jdk-*/bin/java.
    for cachedjava in "$mydir/../node_modules/.cache/vnu-jar/java/"*/bin/java \
                      "$mydir/../node_modules/.cache/vnu-jar/java/"*/Contents/Home/bin/java
    do
        if [ -x "$cachedjava" ]; then
            VALIDATOR_JAVA_CMD="$cachedjava"
            return 0
        fi
    done

    return 1
}

# Determine the validator to use.
# Precedence:
#   1. An explicitly configured $validator (URL or jar path) is always respected.
#   2. Otherwise, if the NPM-installed vnu.jar is present, use it (requires a
#      Java 17+ runtime, resolved by find_validator_java).
#   3. Otherwise, fail with guidance instead of silently using the public service.
validator_set=${validator:-}
if [ -z "$validator_set" ]; then
    if [ -f "$mydir/../node_modules/vnu-jar/build/dist/vnu.jar" ]
    then
        # Note: not called via command substitution - the function sets globals
        # (VALIDATOR_JAVA_CMD, validator_java_version) that we need afterwards,
        # and a subshell would lose them.
        if find_validator_java
        then
            echo "NPM installed validator found."
            validator="$( cd $mydir/../node_modules/ && pwd)/vnu-jar/build/dist/vnu.jar"
            # Pass the runtime along, so mustache_lint.php does not re-resolve it
            # (and does not mistake the auto-installed JRE for a missing java).
            export MUSTACHE_LINT_JAVACMD="$VALIDATOR_JAVA_CMD"
        elif [ -n "$validator_java_version" ]
        then
            validator_java_error "java version too low: $validator_java_version (Java 17 or above is required)."
        else
            validator_java_error "java not found in path."
        fi
    else
        echo "No NPM-installed validator found (node_modules/vnu-jar is missing) and no validator was configured."
        echo "Run 'npm install' in the local_ci directory to install vnu-jar, or configure one explicitly via the \$validator variable (e.g. validator=http://localhost:8888/)."
        exit 1
    fi
fi

echo "Validating using $validator"


export initialcommit=${GIT_PREVIOUS_COMMIT}
export finalcommit=${GIT_COMMIT}
# Fetch all files, excluding files which are renames.
# There is no need to check renames.
if mfiles=$(${mydir}/../list_changed_files/list_changed_files.sh r)
then
    echo "Running mustache lint from $initialcommit to $finalcommit:"
else
    echo "Problems getting the list of changed files."
    exit 1;
fi

# Verify all the changed files.
errorfound=0
for mfile in ${mfiles} ; do
    # Only run on mustache files.
    if [[ "${mfile}" =~ ".mustache" ]] ; then
        fullpath=$gitdir/$mfile

        if [ -e $fullpath ] ; then
            if ! $phpcmd $mydir/mustache_lint.php --filename=$fullpath --validator=$validator --basename=$gitdir
            then
                errorfound=1
            fi
        else
            # This is a bit of a hack, we should really be using git to
            # get actual file contents from the latest commit to avoid
            # this situation. But in the end we are checking against the
            # current state of the codebase, so its no bad thing..
            echo "$fullpath - SKIPPED (file no longer exists)"
        fi
    fi
done

if [[ ${errorfound} -eq 0 ]]; then
    # No syntax errors found, all good.
    echo "No mustache problems found"
    exit 0
fi

echo "Mustache lint problems found"
exit 1
