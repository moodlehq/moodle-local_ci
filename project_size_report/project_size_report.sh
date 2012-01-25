#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to check
# file where results will be sent
resultfile=${WORKSPACE}/project_size_report.csv

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# list of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# checkout pristine copy of the configure branch
cd ${gitdir} && git checkout ${gitbranch} && git fetch && git reset --hard origin/${gitbranch}

# Run phploc against the whole codebase
/opt/local/bin/php ${mydir}/project_size_report.php ${excluded_list} --count-tests --log-csv "${resultfile}" ${gitdir}
