#!/usr/bin/env bash
# $WORKSPACE: Directory where results are saved.
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $npmcmd: Optional, path to the npm executable (global)
# $npminstall: (optional), if set the script will install nodejs stuff. Else, nodejs managing is external.
# $isplugin: (optional), if set we are examining a plugin, some exceptions may be applied.

# Let's be strict. Any problem leads to failure.
set -e

required="WORKSPACE gitdir gitbranch"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file to capture execution output
outputfile=${WORKSPACE}/grunt_process.txt

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply some defaults.
npmcmd=${npmcmd:-npm}
isplugin=${isplugin:-}

cd ${gitdir}
rm -fr config.php
rm -fr ${outputfile}
rm -fr ${outputfile}.stderr

# Prepare all the npm stuff if needed
# (only if the job is in charge of handling it, aka, $npminstall was passed
if [[ -n ${npminstall} ]]; then
    ${mydir}/../prepare_npm_stuff/prepare_npm_stuff.sh
fi

# Ensure we have grunt cli available before continue.
gruntcmd="$(${npmcmd} bin)"/grunt
if [ ! -x $gruntcmd ]; then
    echo "Error: grunt executable not found" | tee "${outputfile}"
    exitstatus=1
else
    # Run grunt against the git repo
    cd ${gitdir}

    # First delete all build files so we can detect stale files in the build dir
    rm -fr $(find . -path '*/yui/build' -type d)
    rm -fr $(find . -path '*/amd/build' -type d)

    # Send both stdout and stderr to files while passing them intact (for callers consumption).
    # The echo here works around a problem where shifter is sending colours (MDL-52591).
    # Run the default task (same as specifying no arguments)
    tasks="default"

    if grep -q ignorefiles Gruntfile.js
    then
        # In 3.2 and later run ignorefiles task
        tasks="$tasks ignorefiles"
    fi

    set +e
    $gruntcmd $tasks --no-color > >(tee "${outputfile}") 2> >(tee "${outputfile}".stderr >&2)
    exitstatus=$?
    set -e
fi

# Cleanup the nodejs installed stuff, not required after run (and prevent other jobs operating on it)
# (only if the job is in charge of handling it, aka, $npminstall was passed
if [[ -n ${npminstall} ]]; then
    rm -fr ${gitdir}/node_modules
fi

if [ $exitstatus -ne 0 ]; then
    echo "ERROR: Problems running grunt" | tee -a "${outputfile}"
    exit $exitstatus
fi

# Look for shifter lint errors that have not ended with the process exiting with error.
shiftererrors=$(cat "${outputfile}".stderr | grep 'shifter \[err\] .* .*' | wc -l)
if (($shiftererrors > 0))
then
    echo "ERROR: Problems running grunt shifter" | tee -a "${outputfile}"
    exit 1
fi

# Look for changes
cd ${gitdir}
grepexclude="grep -v -e npm-shrinkwrap.json"
if [[ -n ${isplugin} ]]; then
    grepexclude="${grepexclude} -e .eslintignore -e .stylelintignore"
fi
echo "Looking for changes, applying some exclusion with ${grepexclude}"
changes=$(git ls-files -m | ${grepexclude} || true)
if [[ -z ${changes} ]]; then
    echo | tee -a "${outputfile}"
    echo "OK: All modules are perfectly processed by grunt" | tee -a "${outputfile}"
    exit 0
else
    echo | tee -a "${outputfile}"
    echo "WARN: Some modules are not properly processed by grunt. Changes detected:" | tee -a "${outputfile}"
    echo | tee -a "${outputfile}"
    for filename in ${changes} ; do
        fullpath=$gitdir/$filename
        echo "GRUNT-CHANGE: ${fullpath}" | tee -a "${outputfile}"
    done
    exit 1
fi
