#!/bin/bash
# $WORKSPACE: Path to the directory where test reults will be sent
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $setversion: 10digits (YYYYMMDD00) to set all versions to. Empty = not set

# Let's go strict (exit on error)
set -e

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
versionregex="^([0-9]{10}(\.[0-9]{2})?)$"

# Prepare the output file where everything will be reported
resultfile=${WORKSPACE}/versions_check_set.txt
echo -n > "${resultfile}"

# Calculate the list of valid components for checks later
# The format of the list is (comma separated):
#    type (plugin, subsystem)
#    name (frankestyle component name)
#    path (full or null)
${phpcmd} ${mydir}/../list_valid_components/list_valid_components.php \
    --basedir="${gitdir}" --absolute=true > "${WORKSPACE}/valid_components.txt"

# Find all the version.php files
allfiles=$( find "${gitdir}" -name version.php )

# Perform various checks with the version.php files
for i in ${allfiles}; do
    echo "- ${i}:" >> "${resultfile}"

    # Calculate prefix for all the regexp operations below
    prefix='$plugin->'
    if [ "${i}" == "${gitdir}/version.php" ]; then
        prefix='$'
    elif [[ "${i}" =~ ${gitdir}/mod/[^/]*/version.php ]]; then
        prefix='$module->'
    fi

    # Verify the file has MOODLE_INTERNAL check
    internal="$( grep 'defined.*MOODLE_INTERNAL.*die.*;$' ${i} || true )"
    if [ -z "${internal}" ]; then
        echo "  + ERROR: File is missing: defined('MOODLE_INTERNAL') || die(); line." >> "${resultfile}"
    fi

    # Verify the file has version defined
    version="$( grep "${prefix}version.*=.*;" ${i} || true )"
    if [ -z "${version}" ]; then
        echo "  + ERROR: File is missing: ${prefix}version = 'xxxxxx' line." >> "${resultfile}"
    fi

    # Verify the version looks correct (10 digit + optional 2) (only if we have version)
    if [ ! -z "${version}" ]; then
        # Extract the version
        if [[ ${version} =~ version\ *=\ *([0-9]{10}(\.[0-9]{2})?)\; ]]; then
            version=${BASH_REMATCH[1]}
            echo "  + INFO: Correct version found: ${version}" >> "${resultfile}"
        else
            version=""
            echo "  + ERROR: No correct version (10 digits + opt 2 more) found" >> "${resultfile}"
        fi
    fi

    # Activity and block plugins cannot have decimals in the version (they are stored into int db columns)
    if [ ! -z "${version}" ] && [[ ${i} =~ /(mod|blocks)/[^/]*/version.php ]]; then
        # Extract the version
        if [[ ${version} =~ [0-9]{10}\.[0-9] ]]; then
            echo "  + ERROR: Activity and block versions cannot have decimal part" >> "${resultfile}"
        else
            echo "  + INFO: Correct mod and blocks version has no decimals" >> "${resultfile}"
        fi
    fi

    # If we are in main version.php
    if [ "${i}" == "${gitdir}/version.php" ]; then
        # TODO: Some checks for main version.php can be added here (release, branch...)
        continue
    fi

    # Verify the file has requires defined
    requires="$( grep "${prefix}requires.*=.*;" ${i} || true )"
    if [ -z "${requires}" ]; then
        echo "  + ERROR: File is missing: ${prefix}requires = 'xxxxxx' line." >> "${resultfile}"
    fi

    # Verify the requires looks correct (10 digit + optional 2) (only if we have requires)
    if [ ! -z "${requires}" ]; then
        # Extract the requires
        if [[ ${requires} =~ requires\ *=\ *([0-9]{10}(\.[0-9]{2})?)\; ]]; then
            requires=${BASH_REMATCH[1]}
            echo "  + INFO: Correct requires found: ${requires}" >> "${resultfile}"
        else
            echo "  + ERROR: No correct requires (10 digits + opt 2 more) found" >> "${resultfile}"
        fi
    fi

    # Verify the file has component defined
    component="$( grep "${prefix}component.*=.*'.*';" ${i} || true )"
    if [ -z "${component}" ]; then
        echo "  + ERROR: File is missing: ${prefix}component = 'xxxxxx' line." >> "${resultfile}"
    fi

    # Verify the component is a correct one for the given dir (only if we have component)
    if [ ! -z "${component}" ]; then
        # Extract the component
        if [[ ${component} =~ component\ *=\ *\'([a-z0-9_]*)\'\; ]]; then
            component=${BASH_REMATCH[1]}
            echo "  + INFO: Correct component found: ${component}" >> "${resultfile}"
            # Now check it's valid for that directory against the list of components
            directory=$( dirname ${i} )
            validdirectory=$( grep "plugin,${component},${directory}" "${WORKSPACE}/valid_components.txt" || true )
            if [ -z "${validdirectory}" ]; then
                echo "  + ERROR: Component ${component} not valid for that file" >> "${resultfile}"
            fi
        else
            echo "  + ERROR: No correct component found" >> "${resultfile}"
        fi
    fi

    # Verify files with maturity are set to stable (warn)
    # Extract maturity
    maturity="$( grep "${prefix}maturity.*=.*;" ${i} || true )"
    if [ ! -z "${maturity}" ]; then
        # Maturity found, verify it is MATURITY_STABLE
        if [[ ${maturity} =~ maturity\ *=\ *(.*)\; ]]; then
            maturity=${BASH_REMATCH[1]}
            # Check it matches one valid maturity
            if [[ ! ${maturity} =~ MATURITY_(ALPHA|BETA|RC|STABLE) ]]; then
                echo "  + ERROR: Maturity ${maturity} not valid" >> "${resultfile}"
            elif [ "${maturity}" != "MATURITY_STABLE" ]; then
                echo "  + WARN: Maturity ${maturity} not ideal for this core plugin" >> "${resultfile}"
            fi
        fi
    fi

    # Look for dependencies (multiline) and verify they are correct
    dependencies="$( sed -n "/${prefix}dependencies/,/);/p" ${i})"
    if [ ! -z "${dependencies}" ]; then
        # Convert dependencies to one line
        dependencies=$( echo ${dependencies} | sed -e "s/[ '\"	]*//g" )
        echo "  + INFO: Dependencies found" >> "${resultfile}"
        # Extract the dependencies
        if [[ ! "${dependencies}" =~ dependencies=array\((.*)\)\; ]]; then
            echo "  + ERROR: Dependencies format does not seem correct" >> "${resultfile}"
        else
            dependencies="$( echo ${BASH_REMATCH[1]} | sed -e 's/,$//g' )"
        fi
        # Split dependencies by comma
        for dependency in $( echo ${dependencies} | sed -e 's/,/ /g' ); do
            echo "  + INFO: Analising dependency: ${dependency}" >> "${resultfile}"
            # Split dependency by '=>'
            if [[ ! ${dependency} =~ (.*)=\>(.*) ]]; then
                echo "  + ERROR: Incorrect dependency format: ${dependency}" >> "${resultfile}"
            fi
            # Validate component and version
            component=${BASH_REMATCH[1]}
            version=${BASH_REMATCH[2]}
            validcomponent=$( grep "plugin,${component}," "${WORKSPACE}/valid_components.txt" || true )
            if [ -z "${validcomponent}" ]; then
                echo "  + ERROR: Component ${component} not valid" >> "${resultfile}"
            fi
            if [[ ! "${version}" =~ ${versionregex} ]]; then
                echo "  + ERROR: Version ${version} not valid" >> "${resultfile}"
            fi
        done
    fi

    # Look for all defined attributes and validate all them are valid
    validattrs="version|release|requires|component|dependencies|cron|maturity"
    grep "^${prefix}[a-z]* *=.*;" ${i} | while read attr; do
        # Extract the attribute
        [[ "${attr}" =~ [^a-z]([a-z]*)\ *=.*\; ]]
        attr=${BASH_REMATCH[1]}
        # Validate and extract attribute
        if [[ ! "${attr}" =~ ^(${validattrs})$ ]]; then
            echo "  + ERROR: Attribute ${attr} is not allowed in version.php files" >> "${resultfile}"
        fi
    done
done

# Look for ERROR in the resultsfile (WARN does not lead to failed build)
count=`grep -P "ERROR:" "$resultfile" | wc -l`

# If we have passed a valid $setversion and there are no errors,
# proceed changing all versions, requires and dependencies
if [ ! -z "${setversion}" ] && (($count == 0)); then
    if [[ ! "${setversion}" =~ ${versionregex} ]]; then
        echo "- ${gitdir}:" >> "${resultfile}"
        echo "  + ERROR: Cannot use incorrect version ${setversion}" >> "${resultfile}"
    else
        # Everything looks, ok, let's replace
        for i in ${allfiles}; do
            # Skip the main version.php file. Let's force to perform manual update there
            # (without it, upgrade won't work)
            if [ "${i}" == "${gitdir}/version.php" ]; then
                continue
            fi
            echo "- ${i}:" >> "${resultfile}"
            replaceregex="s/(=.*)([0-9]{10}(\.[0-9]{2})?)/\${1}${setversion}/g"
            perl -p -i -e ${replaceregex} ${i}
        done
    fi
fi

# Check if there are problems
count=`grep -P "ERROR:" "$resultfile" | wc -l`
if (($count > 0))
then
    exit 1
fi
exit 0
