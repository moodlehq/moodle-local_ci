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

# create destinationdir
mkdir "${WORKSPACE}/${destinationdir}"

# TEMP HACK (global scope dupe function/class names)
rm -fr admin/tool/capability/index.php admin/user/user_bulk_* backup/cc/* filter/algebra/* grade/export/* grade/import/* admin/mailout-debugger.php login/forgot_password_form.php mod/lesson/format.php report/completion/index.php lib/javascript.php theme/javascript.php user/profile.php

# with apigen: http://apigen.org/
#/Users/stronk7/Sites/pear/bin/apigen --source "${WORKSPACE}/backup" --destination "${WORKSPACE}/${destinationdir}" ${excluded_list_wildchars} --exclude "*/${destinationdir}/*" --exclude "*/simpletest/*" --title "Moodle $gitbranch phpdocs" --base-url "" --internal yes --php yes --tree yes --deprecated yes --todo yes --download yes --report "${WORKSPACE}/${destinationdir}_coding_standards_detector.xml" --wipeout yes --colors no --progressbar no --debug yes

# with docblox: http://www.docblox-project.org/
/Users/stronk7/Sites/pear/bin/docblox --directory "${WORKSPACE}" --target "${WORKSPACE}/${destinationdir}" --ignore "${excluded_comma_wildchars},*/${destinationdir}/*,*/simpletest/*" --title "Moodle $gitbranch phpdocs" --template old_ocean --defaultpackagename core --sourcecode
