#!/bin/bash
# $csdir: Directory containing moodle phpcs standard definition
# $gitbranch: Branch we are going to check
# $extraoptions: Extra options to pass to phpcs
# $extraignore: Extra ignore dirs

# file where results will be sent
resultfilename=coding_standards_detector.xml

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# list of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# checkout pristine copy of the configure branch
cd ${WORKSPACE} && git checkout ${gitbranch} && git fetch && git reset --hard origin/${gitbranch}

# Create all the ant build files to specify the modules
/opt/local/bin/php ${mydir}/../generate_component_ant_files/generate_component_ant_files.php --basedir="${WORKSPACE}"

# Look for all the build.xml files, running phpcs for them
buildxml="$( find "${WORKSPACE}" -name build.xml | sed 's/\/build.xml//g' | sort -r)"
for dir in ${buildxml}
    do
        echo "---------- ---------- ----------"
        echo "processing ${dir}"
        echo "with excluded ${excluded_comma_wildchars}"
        /opt/local/bin/php ${mydir}/coding_standards_detector.php --report=checkstyle --report-file="${dir}/${resultfilename}" --standard="${csdir}" --ignore="${excluded_comma_wildchars}${extraignore}" ${extraoptions} ${dir}
        newexclude="$( echo ${dir} | sed s#${WORKSPACE}/##g )"
        excluded_comma_wildchars="${excluded_comma_wildchars},*/${newexclude}/*"
    done

# Always return ok
exit 0
