#!/bin/bash
# $gitbranch: Branch we are going to check
resultfilename=copy_paste_detector.xml

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# list of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# checkout pristine copy of the configure branch
cd ${WORKSPACE} && git checkout ${gitbranch} && git fetch && git reset --hard origin/${gitbranch}

# Process the whole workspace
echo "processing ${WORKSPACE}"
echo "with excluded ${excluded_list}"
/opt/local/bin/php ${mydir}/copy_paste_detector.php ${excluded_list} --quiet --log-pmd "${WORKSPACE}/${resultfilename}" .

# Always return ok
exit 0
