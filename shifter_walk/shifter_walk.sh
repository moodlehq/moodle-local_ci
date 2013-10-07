#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $extrapath: Extra paths to be available (global)
# $npmcmd: Path to the npm executable (global)
# $shifterbase: Base directory where we'll store multiple shifter versions (can be different by branch)
# $shifterversion: Version of shifter to be used by this job

# Let's be strict. Any problem leads to failure.
set +e

# Let add $path to PATH
if [[ -n ${extrapath} ]]; then
    export PATH=${PATH}:${extrapath}
fi

# file to capture execution output
outputfile=${WORKSPACE}/shifter_walk.txt

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure git is ready
cd ${gitdir} && git reset --hard ${gitbranch}
rm -fr config.php
rm -fr ${outputfile}

# Verify we have the shifterbase dir, creating if needed
if [[ ! -d ${shifterbase} ]]; then
    echo "WARN: shifterbase dir (${shifterbase}) not found. Creating it"
    mkdir -p ${shifterbase}
    echo "NOTE: shifterbase dir (${shifterbase}) created"
else
    echo "OK: shifterbase dir (${shifterbase}) found"
fi

# Verify we have already the shifterversion dir, creating if needed
if [[ ! -d ${shifterbase}/${shifterversion} ]]; then
    echo "WARN: shifterversion dir (${shifterversion}) not found. Creating it"
    mkdir -p ${shifterbase}/${shifterversion}
    echo "NOTE: shifterversion dir (${shifterversion}) created"
else
    echo "OK: shifterversion dir (${shifterversion}) found"
fi

# Verify there is a shifter executable available, installing id neeed
if [[ ! -f ${shifterbase}/${shifterversion}/node_modules/shifter/bin/shifter ]]; then
    echo "WARN: shifter executable (${shifterversion}) not found. Installing it"
    cd ${shifterbase}/${shifterversion}
    ${npmcmd} install shifter@${shifterversion}
    echo "NOTE: shifter executable (${shifterversion}) installed"
else
    echo "OK: shifter executable (${shifterversion}) found"
fi

# Run shifter against the git repo
cd ${gitdir}
# First delete all shifted files so we can detect stale files in the build dir
rm -fr `find . -path '*/yui/build' -type d`

${shifterbase}/${shifterversion}/node_modules/shifter/bin/shifter --walk --recursive | tee "${outputfile}"
exitstatus=${PIPESTATUS[0]}
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
