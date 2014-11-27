#!/bin/bash
# $WORKSPACE: Path to the directory where test reults will be sent
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $initalcommit
# $finalcommit

set -e

# Verify everything is set
required="WORKSPACE phpcmd gitdir initialcommit finalcommit"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "ERROR: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if ${mydir}/../list_changed_files/list_changed_files.sh > ${WORKSPACE}/modified_files.txt
then
    echo "INFO: Checking for third party modifications from $initialcommit to $finalcommit"
else
    echo "ERROR: Problems getting the list of changed files."
    exit 1
fi

# Generate the list of valid component directories  and use that to generate third party locations
${mydir}/../list_valid_components/list_valid_components.sh |grep $gitdir | cut -d , -f3 > "${WORKSPACE}/component_directories.txt"
$phpcmd ${mydir}/thirdpartylocations.php < $WORKSPACE/component_directories.txt > $WORKSPACE/thirdpartylocations.txt

while read thirdpartyinfo; do
    # Strip the directory info out for grepping purposes.
    directorylessinfo=`echo $thirdpartyinfo | sed "s#$gitdir/##g"`

    # Get a search string to find modified files.
    search=`echo $directorylessinfo | cut -d, -f1`

    if matches=$(grep "$search" ${WORKSPACE}/modified_files.txt)
    then
        echo "INFO: Detected third party modification in $search"
        thirdpartyfile=`echo $directorylessinfo | cut -d, -f2`
        if grep -q $thirdpartyfile ${WORKSPACE}/modified_files.txt
        then
            echo "INFO: OK $thirdpartyfile modified"
        else
            readmefile=`echo $directorylessinfo | cut -d, -f3`
            if grep -q $readmefile ${WORKSPACE}/modified_files.txt
            then
                echo "INFO: OK $readmefile modified"
            else
                while read -r file; do
                    fullpath=$gitdir/$file
                    echo "$fullpath - WARN: modification to third party library ($search) without update to $thirdpartyfile or ${readmefile}"
                done <<< "$matches"
            fi
        fi
    fi
done <$WORKSPACE/thirdpartylocations.txt

exit 0
