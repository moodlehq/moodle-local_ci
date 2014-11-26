#!/bin/bash
# $gitcmd: Path to the git CLI executable
# $gitdir: Directory containing git repo
# $phpcmd: Path to php CLI exectuable
#
# Based on GIT_PREVIOUS_COMMIT and GIT_COMMIT will list all changed php
# files and run lint on them.
#
set -e

# Verify everything is set
required="gitcmd gitdir phpcmd"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

fulllint=0

if [[ -z "${GIT_PREVIOUS_COMMIT}" ]] || [[ -z "${GIT_COMMIT}" ]] ; then
    # No git diff information. Lint all php files.
    fulllint=1
fi

if [[ ${fulllint} -ne 1 ]]; then
    # We don't need to do a full lint create the variables required by
    # list_changed_files.sh and invoke it
    export initialcommit=${GIT_PREVIOUS_COMMIT}
    export finalcommit=${GIT_COMMIT}
    if mfiles=$(${mydir}/../list_changed_files/list_changed_files.sh)
    then
        echo "Running php syntax check from $initialcommit to $finalcommit:"
    else
        echo "Problems getting the list of changed files. Defaulting to full lint"
        fulllint=1
    fi
fi

if [[ ${fulllint} -eq 1 ]]; then
    mfiles=$(find $gitdir/ -name \*.php ! -path \*/vendor/\* | sed "s|$gitdir/||")
    echo "Running php syntax check on all files:"
fi

# Verify all the changed files.
errorfound=0
for mfile in ${mfiles} ; do
    # Only run on php files.
    if [[ "${mfile}" =~ ".php" ]] ; then
        fullpath=$gitdir/$mfile

        if [ -e $fullpath ] ; then
            if LINTERRORS=$(($phpcmd -l $fullpath >/dev/null) 2>&1)
            then
                echo "$fullpath - OK"
            else
                errorfound=1
                # Filter out the paths from errors:
                ERRORS=$(echo $LINTERRORS | sed "s#$gitdir##")
                echo "$fullpath - ERROR: $ERRORS"
            fi
            if grep -q $'\xEF\xBB\xBF' $fullpath
            then
                echo "$fullpath - ERROR: BOM character found"
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
    echo "No PHP syntax errors found"
    exit 0
fi

echo "PHP syntax errors found."
exit 1
