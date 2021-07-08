#!/usr/bin/env bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to examine
# $format: Optional, name of the format we want to output (defaults to none)
#             can be one of excluded, excluded_grep, excluded_list, excluded_list_wildchars,
#             excluded_comma, excluded_comma_wildchars

# Define directories usually excluded by various CI tools
excluded=".git/
auth/cas/CAS/
admin/tool/componentlibrary/hugo/dist/css/docs.css.map
admin/tool/componentlibrary/docs/
admin/tool/installaddon/tests/fixtures/versionphp/version1.php
backup/bb/bb5.5_to_moodle.xsl
backup/bb/bb6_to_moodle.xsl
backup/cc/schemas/
backup/cc/schemas11/
enrol/lti/tests/fixtures/
lib/adodb/
lib/alfresco/
lib/bennu/
lib/dragmath/
lib/editor/atto/yui/src/rangy/js
lib/editor/atto/tests/fixtures/pretty-good-en.vtt
lib/editor/atto/tests/fixtures/pretty-good-sv.vtt
lib/editor/tinymce/tiny_mce/
lib/editor/tinymce/plugins/moodleimage
lib/editor/tinymce/plugins/pdw
lib/editor/tinymce/plugins/spellchecker
lib/evalmath/
lib/excel/
lib/flowplayer/
lib/gallery/
lib/google/
lib/horde/
lib/htmlpurifier/
lib/jabber/
lib/jquery/
lib/lessphp/
lib/minify/
lib/overlib/
lib/password_compat/
lib/pear/
lib/phpexcel/
lib/phpmailer/
lib/simplepie/
lib/simpletestlib/
lib/smarty/
lib/spikephpcoverage/
lib/swfobject/
lib/tcpdf/
lib/tests/fixtures/messageinbound/
lib/tests/fixtures/timezonewindows.xml
lib/typo3/
lib/yui/2.9.0/
lib/yui/3.4.1/
lib/yui/3.5.1/
lib/yui/phploader/
lib/yuilib/
lib/zend/
lib/base32.php
lib/csshover.htc
lib/cookies.js
lib/html2text.php
lib/markdown/
lib/markdown.php
lib/xhprof/xhprof_html/
lib/xhprof/xhprof_lib/
lib/xmlize.php
mod/lti/OAuthBody.php
mod/wiki/tests/fixtures/
mod/assign/feedback/editpdf/fpdi/
node_modules/
question/format/qti_two/templates/
repository/s3/S3.php
repository/url/locallib.php
theme/boost/style/moodle.css
theme/bootstrapbase/less/bootstrap
theme/classic/style/moodle.css
theme/mymobile/javascript/
theme/mymobile/jquery/
theme/mymobile/style/jmobile
vendor/
webservice/amf/testclient/AMFTester.mxml
webservice/amf/testclient/customValidators/JSONValidator.as
work/
yui/build/
*.csv
*.gif
*.jpg
*.ics
*.png
*.svg"

# Normalize gitdir, we don't want trailing slashes there ever.
gitdir=$(echo "${gitdir}" | sed -n 's/\/*$//p')

# Now, look for all the thirdpartylibs.xml in codebase, adding
# all the found locations to the list of excluded.
if [[ -n "${gitdir}" ]]; then
    for file in $(find "${gitdir}" -name thirdpartylibs.xml); do
        absolutebase=$(dirname ${file})
        # Everything relative to gitdir (diroot).
        base=${absolutebase#${gitdir}/}
        for location in $(sed -n 's/^.*<location>\(.*\)<\/location>.*$/\1/p' "${file}"); do
            if [[ -d "${gitdir}/${base}/${location}" ]]; then
                excluded+=$'\n'"${base}/${location}/"
            else
                excluded+=$'\n'"${base}/${location}"
            fi
        done
    done
fi

export LC_ALL=C
# Sort and get rid of dupes, they (maybe) are legion.
excluded=$(echo "${excluded}" | sort -u)

# Some well-known exceptions... to be deleted once the branch
# gets out from support
if [[ ${gitbranch} == "MOODLE_19_STABLE" ]]
then
excluded="${excluded}
lib/yui/"
fi

# Exclude syntax for grep commands (egrep-like regexp)
excluded_grep=""
while read -r i; do
    excluded_grep="${excluded_grep}|/${i}"
done <<< "${excluded}"
excluded_grep=${excluded_grep#|}
excluded_grep=${excluded_grep//\./\\.}
excluded_grep=${excluded_grep//\*/.\*}

# Exclude syntax for phpcpd/phploc../phploc... (list of exclude parameters without trailing slash)
excluded_list=""
while read -r i; do
    excluded_list="${excluded_list} --exclude ${i%\/}"
done <<< "${excluded}"

# Exclude syntax for apigen (list of exclude parameters with * wildcards)
excluded_list_wildchars=""
while read -r i; do
    excluded_list_wildchars="${excluded_list_wildchars} --exclude */${i}*"
done <<< "${excluded}"

# Exclude syntax for phpmd (comma separated)
excluded_comma=""
while read -r i; do
    excluded_comma="${excluded_comma},${i}"
done <<< "${excluded}"
excluded_comma=${excluded_comma#,}

# Exclude syntax for phpcs (coma separated with * wildcards)
excluded_comma_wildchars=""
while read -r i; do
    excluded_comma_wildchars="${excluded_comma_wildchars},*/${i}*"
done <<< "${excluded}"
excluded_comma_wildchars=${excluded_comma_wildchars#,}
excluded_comma_wildchars=${excluded_comma_wildchars//\./\\.}

# Finally, if requested, and the variable exists and is not empty, output it
if [[ -n ${format} ]] && [[ -n ${!format} ]]; then
    echo "${!format}"
fi
