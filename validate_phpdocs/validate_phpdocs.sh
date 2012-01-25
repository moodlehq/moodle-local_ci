#!/bin/bash
# $gitbranch: Branch we are going to check
# file where results will be sent
destinationdir=phpdocs

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# list of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# checkout pristine copy of the configure branch
cd ${WORKSPACE} && git checkout ${gitbranch} && git fetch && git reset --hard origin/${gitbranch}

# Create all the ant build files to specify the modules
/opt/local/bin/php ${mydir}/../generate_component_ant_files/generate_component_ant_files.php --basedir="${WORKSPACE}"

# Look for all the build.xml files, running docblox validation for them
# with docblox: http://www.docblox-project.org/
# (http://docs.docblox-project.org/for-users/validating-documentation-in-your-code.html)
buildxml="$( find "${WORKSPACE}" -name build.xml | sed 's/\/build.xml//g' | sort -r)"
for dir in ${buildxml}
    do
        echo "---------- ---------- ----------"
        echo "processing ${dir}"
        echo "with excluded ${excluded_comma_wildchars}"
        /Users/stronk7/Sites/pear/bin/docblox --directory "${dir}" --target "${dir}" --ignore "${excluded_comma_wildchars}" --template checkstyle --defaultpackagename core
        newexclude="$( echo ${dir} | sed s#${WORKSPACE}/##g )"
        excluded_comma_wildchars="${excluded_comma_wildchars},*/${newexclude}/*"
    done

# Always return ok
exit 0
