#!/bin/bash
# $WORKSPACE: Directory where results are saved.
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $extrapath: Extra paths to be available (global)
# $npmcmd: Path to the npm executable (global)
# $npmbase: Base directory where we'll store multiple npm packages versions (subdirectories per branch)

# Let's be strict. Any problem leads to failure.
set -e

# Let add $extrapath to PATH
if [[ -n ${extrapath} ]]; then
    export PATH=${PATH}:${extrapath}
fi

required="WORKSPACE gitdir gitbranch extrapath npmcmd npmbase"
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


cd ${gitdir}
rm -fr config.php
rm -fr ${outputfile}

# Verify we have the npmbase dir, creating if needed
if [[ ! -d ${npmbase} ]]; then
    echo "WARN: npmbase dir (${npmbase}) not found. Creating it"
    mkdir -p ${npmbase}
    echo "NOTE: npmbase dir (${npmbase}) created"
else
    echo "OK: npmbase dir (${npmbase}) found"
fi

# Verify we have already the gitbranch dir, creating if needed
if [[ ! -d ${npmbase}/${gitbranch}/node_modules ]]; then
    echo "WARN: npmbase for branch (${gitbranch}) not found. Creating it"
    mkdir -p ${npmbase}/${gitbranch}/node_modules
    echo "NOTE: npmbase for branch (${gitbranch}) created"
else
    echo "OK: npmbase for branch (${gitbranch}) found"
fi

# Linking it.
ln -nfs ${npmbase}/${gitbranch}/node_modules ${gitdir}/node_modules

# Verify there is a grunt executable available, installing if missing
if [[ ! -f ${gitdir}/node_modules/grunt-cli/bin/grunt ]]; then
    echo "WARN: grunt-cli executable not found. Installing everything"
    ${npmcmd} install grunt-cli
fi

# Always run npm install to keep our npm packages correct
${npmcmd} install

# Run grunt against the git repo
cd ${gitdir}
# First delete all build files so we can detect stale files in the build dir
rm -fr $(find . -path '*/yui/build' -type d)
rm -fr $(find . -path '*/amd/build' -type d)

${gitdir}/node_modules/grunt-cli/bin/grunt --no-color | tee "${outputfile}"
exitstatus=${PIPESTATUS[0]}

# Cleanup symlink as not required after run (and prevent other jobs operating on it)
rm ${gitdir}/node_modules

if [ $exitstatus -ne 0 ]; then
    echo "ERROR: Problems running grunt" | tee -a "${outputfile}"
    exit $exitstatus
fi

# Look for changes
cd ${gitdir}
changes=$(git ls-files -m)
if [[ -z ${changes} ]]; then
    echo | tee -a "${outputfile}"
    echo "OK: All modules are perfectly processed by grunt" | tee -a "${outputfile}"
    exit 0
else
    echo | tee -a "${outputfile}"
    echo "ERROR: Some modules are not properly processed by grunt. Changes detected:" | tee -a "${outputfile}"
    echo | tee -a "${outputfile}"
    for filename in ${changes} ; do
        fullpath=$gitdir/$filename
        echo "GRUNT-CHANGE: ${fullpath}" | tee -a "${outputfile}"
    done
    exit 1
fi
