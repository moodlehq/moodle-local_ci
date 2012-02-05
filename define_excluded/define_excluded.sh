#!/bin/bash

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
lib/yui/
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
question/format/qti_two/templates/
repository/s3/S3.php
repository/url/locallib.php
search/
theme/mymobile/javascript/
theme/mymobile/style/jmobile
webservice/amf/testclient/AMFTester.mxml
webservice/amf/testclient/customValidators/JSONValidator.as
work/"

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
