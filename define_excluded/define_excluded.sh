#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to examine

# Define directories usually excluded by various CI tools
excluded=".git/
auth/cas/CAS/
backup/bb/bb5.5_to_moodle.xsl
backup/bb/bb6_to_moodle.xsl
backup/cc/schemas/
backup/cc/schemas11/
lib/adodb/
lib/alfresco/
lib/bennu/
lib/dragmath/
lib/editor/tinymce/tiny_mce/
lib/editor/tinymce/plugins/moodleimage
lib/editor/tinymce/plugins/spellchecker
lib/evalmath/
lib/excel/
lib/flowplayer/
lib/gallery/
lib/htmlpurifier/
lib/jabber/
lib/minify/
lib/overlib/
lib/pear/
lib/phpmailer/
lib/simplepie/
lib/simpletestlib/
lib/smarty/
lib/spikephpcoverage/
lib/swfobject/
lib/tcpdf/
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
lib/markdown.php
lib/xhprof/xhprof_html/
lib/xhprof/xhprof_lib/
lib/xmlize.php
mod/lti/OAuthBody.php
mod/wiki/tests/fixtures/
question/format/qti_two/templates/
repository/s3/S3.php
repository/url/locallib.php
search/
theme/mymobile/javascript/
theme/mymobile/style/jmobile
webservice/amf/testclient/AMFTester.mxml
webservice/amf/testclient/customValidators/JSONValidator.as
work/"

# Some well-known exceptions... to be deleted once the branch
# gets out from support
if [[ ${gitbranch} == "MOODLE_19_STABLE" ]]
then
excluded="${excluded}
lib/yui/"
fi
if [[ ${gitbranch} == "MOODLE_20_STABLE" ]]
then
excluded="${excluded}
lib/yui/2.8.2/
lib/yui/3.2.0/
lib/yui/readme_moodle.txt"
fi

# Exclude syntax for grep commands (egrep-like regexp)
excluded_grep=""
for i in ${excluded}
do
    excluded_grep="${excluded_grep}|/${i}"
done
excluded_grep=${excluded_grep//|\/\.git/\/.git}
excluded_grep=${excluded_grep//\./\\.}

# Exclude syntax for phpcpd (list of exclude parameters)
excluded_list=""
for i in ${excluded}
do
    excluded_list="${excluded_list} --exclude ${i}"
done

# Exclude syntax for apigen (list of exclude parameters with * wildcards)
excluded_list_wildchars=""
for i in ${excluded}
do
    excluded_list_wildchars="${excluded_list_wildchars} --exclude */${i}*"
done

# Exclude syntax for phpmd (comma separated)
excluded_comma=""
for i in ${excluded}
do
    excluded_comma="${excluded_comma},${i}"
done
excluded_comma=${excluded_comma//,\.git/.git}

# Exclude syntax for phpcs (coma separated with * wildcards)
excluded_comma_wildchars=""
for i in ${excluded}
do
    excluded_comma_wildchars="${excluded_comma_wildchars},*/${i}*"
done
excluded_comma_wildchars=${excluded_comma_wildchars//,\*\/\.git/*\/.git}
excluded_comma_wildchars=${excluded_comma_wildchars//\./\\.}
