#!/usr/bin/env bash
# $WORKSPACE: Directory where results/artifacts will be created
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $gitcmd: Path to the git executable (global)
# $npmcmd: Optional, path to the npm executable (global)
# $shifterversion: (optional) Version of shifter to be used by this job

# Let's be strict. Any problem leads to failure.
set +e

# Verify everything is set
required="WORKSPACE gitdir gitbranch gitcmd"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file to capture execution output
outputfile=${WORKSPACE}/shifter_walk.txt

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply some defaults.
npmcmd=${npmcmd:-npm}

# Ensure git is ready
cd ${gitdir} && git reset --hard ${gitbranch}
rm -fr config.php
rm -fr ${outputfile}

# Prepare all the npm stuff if needed unconditionally
. ${mydir}/../prepare_npm_stuff/prepare_npm_stuff.sh

shiftercmd="$(${npmcmd} bin)"/shifter
if [ ! -x $shiftercmd ]; then
    echo "Error: shifter executable not found" | tee "${outputfile}"
    exit 1
fi

# First delete all shifted files so we can detect stale files in the build dir
rm -fr `find . -path '*/yui/build' -type d`

set +e
${shiftercmd} --walk --recursive | tee "${outputfile}"
exitstatus=${PIPESTATUS[0]}
set -e

if [ $exitstatus -ne 0 ]; then
    echo "ERROR: Problems running shifter" | tee -a "${outputfile}"
    exit $exitstatus
fi

# Look for changes
cd ${gitdir}
changes=$(git ls-files -m)
if [[ -z ${changes} ]]; then
    echo | tee -a "${outputfile}"
    echo "OK: All modules are perfectly shiftered" | tee -a "${outputfile}"
    exit 0
else
    echo | tee -a "${outputfile}"
    echo "ERROR: Some modules are not properly shiftered. Changes detected:" | tee -a "${outputfile}"
    echo | tee -a "${outputfile}"
    echo "${changes}" | tee -a "${outputfile}"
    exit 1
fi
