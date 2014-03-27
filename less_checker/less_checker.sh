#!/bin/bash
# $WORKSPACE: Directory where results/artifacts will be created
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to verify
# $extrapath: Extra paths to be available (global)
# $gitcmd: Path to the git executable (global)
# $npmcmd: Path to the npm executable (global)
# $recessbase: Base directory where we'll store multiple recess versions (can be different by branch)
# $recessversion: Version of recess to be used by this job

# Let's be strict. Any problem leads to failure.
set -e

# Verify everything is set
required="WORKSPACE gitdir gitbranch extrapath gitcmd npmcmd recessbase recessversion"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Let add $path to PATH
if [[ -n ${extrapath} ]]; then
    export PATH=${extrapath}:${PATH}
fi

# file to capture execution output
outputfile=${WORKSPACE}/less_checker.txt

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure git is ready
cd ${gitdir} && ${gitcmd} reset --hard ${gitbranch}
rm -fr config.php
rm -fr ${outputfile}

# Verify we have the recessbase dir, creating if needed
if [[ ! -d ${recessbase} ]]; then
    echo "WARN: recessbase dir (${recessbase}) not found. Creating it"
    mkdir -p ${recessbase}
    echo "NOTE: recessbase dir (${recessbase}) created"
else
    echo "OK: recessbase dir (${recessbase}) found"
fi

# Verify we have already the recessversion dir, creating if needed
if [[ ! -d ${recessbase}/${recessversion} ]]; then
    echo "WARN: recessversion dir (${recessversion}) not found. Creating it"
    mkdir -p ${recessbase}/${recessversion}
    echo "NOTE: recessversion dir (${recessversion}) created"
else
    echo "OK: recessversion dir (${recessversion}) found"
fi

# Verify there is a recess executable available, installing id neeed
if [[ ! -f ${recessbase}/${recessversion}/node_modules/recess/bin/recess ]]; then
    echo "WARN: recess executable (${recessversion}) not found. Installing it"
    cd ${recessbase}/${recessversion}
    ${npmcmd} install recess@${recessversion}
    echo "NOTE: recess executable (${recessversion}) installed"
else
    echo "OK: recess executable (${recessversion}) found"
fi

# Iterate over all themes
exitstatus=0
echo "Processing ${gitdir}/theme" | tee "${outputfile}"
for themepath in $(ls ${gitdir}/theme); do
    # Skip non directories.
    if [[ ! -d "${gitdir}/theme/${themepath}" ]]; then
        continue
    fi
    # Some basic theme checks
    echo "  Processing ${themepath}" | tee -a "${outputfile}"
    if [[ ! -f "${gitdir}/theme/${themepath}/config.php" ]]; then
        echo "    - WARN: The theme is missing a config.php file" | tee -a "${outputfile}"
        exitstatus=1
    fi
    if [[ ! -f "${gitdir}/theme/${themepath}/version.php" ]]; then
        echo "    - WARN: The theme is missing a version.php file" | tee -a "${outputfile}"
        exitstatus=1
    fi
    if [[ ! -d "${gitdir}/theme/${themepath}/style" ]]; then
        echo "    - WARN: The theme is missing a style directory" | tee -a "${outputfile}"
        exitstatus=1
    fi
    # Verify if the theme is using built-in compiler for any less file (only one is supported)
    # and perform some custom checks with it
    builtinlessfile=$(sed -nr 's/^\$THEME->lessfile *= *'\''(.*)'\'';$/\1/p' "${gitdir}/theme/${themepath}/config.php")
    if [[ -n "${builtinlessfile}" ]]; then
        echo "    - NOTE: Found \$THEME->lessfile with '${builtinlessfile}' contents" | tee -a "${outputfile}"
        # Confirm the less file exists
        builtinlessfile=${builtinlessfile}.less
        if [[ ! -f "${gitdir}/theme/${themepath}/less/${builtinlessfile}" ]]; then
            echo "      - ERROR: /theme/${themepath}/less/${builtinlessfile} not found" | tee -a "${outputfile}"
            exitstatus=1
        fi
        # Compile the .less file to verify it's basically correct
        echo "      - Compiling .less file: ${gitdir}/theme/${themepath}/less/${builtinlessfile}" | tee -a "${outputfile}"
        set +e
        ${recessbase}/${recessversion}/node_modules/recess/bin/recess --compile --compress \
                "${gitdir}/theme/${themepath}/less/${builtinlessfile}" > /dev/null
        compilestatus=${PIPESTATUS[0]}
        set -e
        if [ $exitstatus -ne 0 ]; then
            echo "        - ERROR: Problems compiling (recess) the file" | tee -a "${outputfile}"
            exitstatus=1
        else
            echo "        - OK: File compiled (recess) without errors" | tee -a "${outputfile}"
        fi
    fi

    # Look for .less files not placed properly
    for lessfile in $(find ${gitdir}/theme/${themepath} -name "*.less"); do
        if [[ ! $lessfile =~ "${gitdir}/theme/${themepath}/less/" ]]; then
            echo "    - ERROR: Wrong path for .less file found: $lessfile" | tee -a "${outputfile}"
            exitstatus=1
        fi
    done
    # Look if the theme has a less directory
    if [[ ! -d "${gitdir}/theme/${themepath}/less" ]]; then
        echo "    - NOTE: Skipped, theme does not have a less directory to process" | tee -a "${outputfile}"
        continue;
    fi
    # Get all the correct .less files in the theme
    for lessfile in $(ls ${gitdir}/theme/${themepath}/less/*.less); do
        filename=$(basename "$lessfile")
        filename="${filename%.*}"
        cssfile="${gitdir}/theme/${themepath}/style/${filename}.css"
        echo "    - Verifying .less file: ${lessfile}" | tee -a "${outputfile}"
        # If the lessfile being processed is the builtinlessfile, we can safely skip any check on it
        if [[ "$(basename "$lessfile")" == "${builtinlessfile}" ]]; then
            echo "      - OK: Skipping .less file. It's handled by builtin compiler" | tee -a "${outputfile}"
            continue;
        fi
        # Verify .css counterpart exists
        if [[ ! -f "${cssfile}" ]]; then
            echo "      - ERROR: css counterpart not found: ${cssfile}" | tee -a "${outputfile}"
            exitstatus=1
            continue
        else
            echo "      - OK: css counterpart found: ${cssfile}" | tee -a "${outputfile}"
        fi
        # Compile the .less file replacing current .css
        echo "    - Compiling .less file: ${lessfile}" | tee -a "${outputfile}"
        set +e
        ${recessbase}/${recessversion}/node_modules/recess/bin/recess --compile --compress \
                "${lessfile}" > "${cssfile}"
        compilestatus=${PIPESTATUS[0]}
        set -e
        if [ $exitstatus -ne 0 ]; then
            echo "      - ERROR: Problems compiling (recess) the file" | tee -a "${outputfile}"
            exitstatus=1
        else
            echo "      - OK: File compiled (recess) without errors" | tee -a "${outputfile}"
        fi
    done
done

# Arrived here, look for changes globally
cd ${gitdir}
changes=$(${gitcmd} ls-files -m)
if [[ -z ${changes} ]]; then
    echo | tee -a "${outputfile}"
    echo "OK: All .less files are perfectly compiled and matching git contents" | tee -a "${outputfile}"
else
    echo | tee -a "${outputfile}"
    echo "ERROR: Some .less files are not matching git contents. Changes detected:" | tee -a "${outputfile}"
    echo | tee -a "${outputfile}"
    echo "${changes}" | tee -a "${outputfile}"
    echo | tee -a "${outputfile}"
    exitstatus=1
fi
exit ${exitstatus}
