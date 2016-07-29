#!/usr/bin/env bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to check
# $pearpath: Path where the pear executables are available
# $phpcmd: php cli executable

# file where results will be sent
resultfile=${WORKSPACE}/project_size_report.csv

# add the PEAR path
PATH="$PATH:/opt/local/bin/:$pearpath"; export PATH

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# list of excluded dirs
. ${mydir}/../define_excluded/define_excluded.sh

# checkout pristine copy of the configure branch
cd ${gitdir} && git checkout ${gitbranch} && git fetch && git reset --hard origin/${gitbranch}

# Run phploc against the whole codebase
phploc ${excluded_list} --count-tests --log-csv "${resultfile}" ${gitdir}
