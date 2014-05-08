#!/bin/bash
# $WORKSPACE: Path to the directory where test reults will be sent
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $setversion: 10digits (YYYYMMDD00) to set all versions to. Empty = not set

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE phpcmd gitdir"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
versionregex="^([0-9]{10}(\.[0-9]{2})?)$"

# Prepare the output file where everything will be reported
resultfile=${WORKSPACE}/versions_check_set.txt
echo -n > "${resultfile}"

# First of all, guess the current branch from main version.php file ($branch). We'll be using
# it to decide about different checks later.
currentbranch="$( grep "\$branch.*=.*;" "${gitdir}/version.php" || true )"
if [ -z "${currentbranch}" ]; then
    echo "+ ERROR: Main version.php file is missing: \$branch = 'xx' line." >> "${resultfile}"
elif [[ ${currentbranch} =~ branch\ *=\ *.([0-9]{2,3}).\; ]]; then
    currentbranch=${BASH_REMATCH[1]}
    echo "+ INFO: Correct main version.php branch found: ${currentbranch}" >> "${resultfile}"
else
    currentbranch="27"
    echo "+ WARN: No correct main version.php branch 'XY[Z]' found. Using ${currentbranch}" >> "${resultfile}"
fi

# Calculate the list of valid components for checks later
# The format of the list is (comma separated):
#    type (plugin, subsystem)
#    name (frankestyle component name)
#    path (full or null)
${mydir}/../list_valid_components/list_valid_components.sh > "${WORKSPACE}/valid_components.txt"

# Find all the version.php files
allfiles=$( find "${gitdir}" -name version.php | awk -F "/" '{print NF-1"\t"$0}' | sort -n | cut -f 2- )

# version.php files to ignore
ignorefiles="(local/(ci|codechecker|moodlecheck)/version.php|.*/tests/fixtures/.*/version.php)"

# Perform various checks with the version.php files
for i in ${allfiles}; do
    # Exclude the version.php if matches ignorefiles
    if [[ "${i}" =~ ${gitdir}/${ignorefiles} ]]; then
        echo "- ${i}: Ignored"  >> "${resultfile}"
        continue;
    fi

    echo "- ${i}:" >> "${resultfile}"

    # Calculate prefix for all the regexp operations below
    prefix='\$plugin->'
    if [ "${i}" == "${gitdir}/version.php" ]; then
        prefix='\$'
    elif [[ "${i}" =~ ${gitdir}/mod/[^/]*/version.php ]]; then
        # Before 2.7, both "module" and "plugin" were allowed in core for activity modules. For 2.7 and up
        # only the default "plugin" is allowed.
        if [[ "${currentbranch}" -lt "27" ]]; then
            prefix='\$(module|plugin)->'
        fi
    fi

    # Verify the file has MOODLE_INTERNAL check
    internal="$( grep 'defined.*MOODLE_INTERNAL.*die.*;$' ${i} || true )"
    if [ -z "${internal}" ]; then
        echo "  + ERROR: File is missing: defined('MOODLE_INTERNAL') || die(); line." >> "${resultfile}"
    fi

    # Verify the file has version defined
    version="$( grep -P "${prefix}version.*=.*;" ${i} || true )"
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
        mainversion=${version}

        mainrelease="$( grep "${prefix}release.*=.*;" ${i} || true )"
        if [ -z "${mainrelease}" ]; then
            echo "  + ERROR: File is missing: ${prefix}release = 'xxxxxx' line." >> "${resultfile}"
        fi
        if [[ ${mainrelease} =~ release\ *=\ *.([0-9]\.[0-9]{1,2}(\.[0-9]{1,2})?)[^0-9].*\(Build:\ *[0-9]{8}\).\; ]]; then
            mainrelease=${BASH_REMATCH[1]}
            echo "  + INFO: Correct release found: ${mainrelease}" >> "${resultfile}"
        else
            mainrelease=""
            echo "  + ERROR: No correct version 'X.YY[+|beta|rc] (Build: YYYYMMDD)' found" >> "${resultfile}"
        fi

        mainbranch="$( grep "${prefix}branch.*=.*;" ${i} || true )"
        if [ -z "${mainbranch}" ]; then
            echo "  + ERROR: File is missing: ${prefix}branch = 'xx' line." >> "${resultfile}"
        fi
        if [[ ${mainbranch} =~ branch\ *=\ *.([0-9]{2,3}).\; ]]; then
            mainbranch=${BASH_REMATCH[1]}
            echo "  + INFO: Correct branch found: ${mainbranch}" >> "${resultfile}"
        else
            mainbranch=""
            echo "  + ERROR: No correct branch 'XY[Z]' found" >> "${resultfile}"
        fi

        mainmaturity="$( grep "${prefix}maturity.*=.*;" ${i} || true )"
        if [ -z "${mainmaturity}" ]; then
            echo "  + ERROR: File is missing: ${prefix}maturity = MATURITY_XXX line." >> "${resultfile}"
        fi
        if [[ ${mainmaturity} =~ maturity\ *=\ *(MATURITY_(ALPHA|BETA|RC|STABLE))\; ]]; then
            mainmaturity=${BASH_REMATCH[1]}
            echo "  + INFO: Correct mainmaturity found: ${mainmaturity}" >> "${resultfile}"
        else
            mainmaturity=""
            echo "  + ERROR: No correct mainmaturity MATURITY_XXXX found" >> "${resultfile}"
        fi

        # Verify branch matches normalised release
        normalisedrelease=${mainrelease/\./}
        if [[ ! ${normalisedrelease} =~ ${mainbranch} ]]; then
            echo "  + ERROR: Branch ${mainbranch} does not match release ${mainrelease}"  >> "${resultfile}"
        else
            echo "  + INFO: Branch ${mainbranch} matches release ${mainrelease}"  >> "${resultfile}"
        fi

        continue
    fi

    # Tests following are not applied to main version.php but to all the other versions

    # Verify the file has requires defined
    requires="$( grep -P "${prefix}requires.*=.*;" ${i} || true )"
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
            requires=""
            echo "  + ERROR: No correct requires (10 digits + opt 2 more) found" >> "${resultfile}"
        fi
    fi

    # Verify the requires is <= main version
    if [ -z "${mainversion}" ]; then
        echo "  + ERROR: Processing requires before knowing about main version." >> "${resultfile}"
    else
        # Float comparison
        satisfied=$( echo "${requires} <= ${mainversion}" | bc )
        if [ "${satisfied}" != "0" ]; then
            echo "  + INFO: Requires ${requires} satisfies main version." >> "${resultfile}"
        else
            echo "  + ERROR: Requires ${requires} does not satisfy main version ${mainversion}." >> "${resultfile}"
        fi
    fi

    # Verify the file has component defined
    component="$( grep -P "${prefix}component.*=.*'.*';" ${i} || true )"
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
    maturity="$( grep -P "${prefix}maturity.*=.*;" ${i} || true )"
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
    grep -P "^${prefix}[a-z]* *=.*;" ${i} | while read attr; do
        # Extract the attribute
        [[ "${attr}" =~ [^a-z]([a-z]*)\ *=.*\; ]]
        attr=${BASH_REMATCH[1]}
        # Validate and extract attribute
        if [[ ! "${attr}" =~ ^(${validattrs})$ ]]; then
            echo "  + ERROR: Attribute ${attr} is not allowed in version.php files" >> "${resultfile}"
        fi
    done
done

# Now, look for backup/backup.class.php to ensure it matches main /version.php
echo "- ${gitdir}/backup/backup.class.php:" >> "${resultfile}"
if [ ! -f "${gitdir}/backup/backup.class.php" ]; then
    echo "  + ERROR: File backup/backup.class.php not found" >> "${resultfile}"
else
    # - backup::VERSION must be always >= $version (8 first digits comparison)
    backupversion="$( grep "const.*VERSION.*=.*;" "${gitdir}/backup/backup.class.php" || true )"
    if [ -z "${backupversion}" ]; then
        echo "  + ERROR: backup/backup.class.php is missing: const VERSION = XXXXX line." >> "${resultfile}"
    fi
    if [[ ${backupversion} =~ const\ *VERSION\ *=\ *([0-9]{10})\; ]]; then
        backupversion=${BASH_REMATCH[1]}
        echo "  + INFO: Correct backup version found: ${backupversion}" >> "${resultfile}"
    else
        backupversion=""
        echo "  + ERROR: No correct backup version YYYYYMMDDZZ found" >> "${resultfile}"
    fi
    # But this only applies to STABLE branches, let's try to get current one
    gitbranch=$( basename $( cd "${gitdir}" && git symbolic-ref -q HEAD ) )
    if [[ ${gitbranch} =~ MOODLE_[0-9]*_STABLE ]]; then
        cutmainversion=$( echo ${mainversion} | cut -c -8 )
        cutbackupversion=$( echo ${backupversion} | cut -c -8 )
        # Integer comparison (give it 15 days before start failing and requiring to adjust stable backup version)
        satisfied=$( echo "(${cutbackupversion} + 15 ) >= ${cutmainversion}" | bc )
        if [ "${satisfied}" != "0" ]; then
            echo "  + INFO: Backup version ${cutbackupversion} satisfies main version." >> "${resultfile}"
        else
            echo "  + ERROR: Backup version ${cutbackupversion} does not satisfy main version ${cutmainversion}." >> "${resultfile}"
        fi
    else
        echo "  + INFO: Detected git branch ${gitbranch}. Skipping the backup version verification." >> "${resultfile}"
    fi

    # - backup::RELEASE must match $release (X.Y only)
    backuprelease="$( grep "const.*RELEASE.*=.*;" "${gitdir}/backup/backup.class.php" || true )"
    if [ -z "${backuprelease}" ]; then
        echo "  + ERROR: backup/backup.class.php is missing: const RELEASE = 'X.Y' line." >> "${resultfile}"
    fi
    if [[ ${backuprelease} =~ const\ *RELEASE\ *=\ *.([0-9]\.[0-9]{1,2}).\; ]]; then
        backuprelease=${BASH_REMATCH[1]}
        echo "  + INFO: Correct backup release found: ${backuprelease}" >> "${resultfile}"
    else
        backuprelease=""
        echo "  + ERROR: No correct backup release 'X.Y' found" >> "${resultfile}"
    fi
    if [[ ! ${mainrelease} =~ ${backuprelease} ]]; then
        echo "  + ERROR: Backup release ${backuprelease} does not match main release ${mainrelease}"  >> "${resultfile}"
    else
        echo "  + INFO: Backup release ${backuprelease} matches main release ${mainrelease}"  >> "${resultfile}"
    fi
fi

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
            # Exclude the version.php if matches ignorefiles
            if [[ "${i}" =~ ${gitdir}/${ignorefiles} ]]; then
                echo "- ${i}: Ignored"  >> "${resultfile}"
                continue;
            fi
            # Skip the main version.php file. Let's force to perform manual update there
            # (without it, upgrade won't work)
            if [ "${i}" == "${gitdir}/version.php" ]; then
                continue
            fi
            echo "- ${i}:" >> "${resultfile}"
            replaceregex="s/(=>? *)([0-9]{10}(\.[0-9]{2})?)/\${1}${setversion}/g"
            perl -p -i -e "${replaceregex}" ${i}
        done
        # also the backup/backup.class.php file
        i=${gitdir}/backup/backup.class.php
        echo "- ${i}:" >> "${resultfile}"
        replaceregex="s/(const *VERSION *= *)([0-9]{10}(\.[0-9]{2})?)/\${1}${setversion}/g"
        perl -p -i -e "${replaceregex}" ${i}
    fi
fi

# Check if there are problems
count=`grep -P "ERROR:" "$resultfile" | wc -l`
if (($count > 0))
then
    exit 1
fi
exit 0
