<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Convert input .txt files to checkstyle xml format
 *
 * This script will convert the (textual) output from
 * various jobs one checkstyle-like xml formal
 * for easier integration in other CI tools/reports. It's used by
 * some jobs like the remote_branch_checker one.
 *
 * @category   ci
 * @package    local_ci
 * @copyright  2015 Dan Poltawski
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

require_once(__DIR__.'/../phplib/clilib.php');

// now get cli options
list($options, $unrecognized) = cli_get_params(
    array('help' => false, 'format' => false),
    array('h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$unrecognised}\n Please use --help option.");

}

$validformats = array('phplint', 'thirdparty', 'gruntdiff', 'shifter', 'mustachelint', 'gherkinlint');


    $help =
"Convert text input to checkstyle xml format

Options:
-h, --help            Print out this help
--format              (".implode(',', $validformats).")

Example:
\$ php local/ci/checkstyle_converter/checkstyle_converter.php < file.txt > file.xml
";

if ($options['help']) {
    echo $help;
    exit(0);
}

if (!isset($options['format'])) {
    echo "ERROR: Format required. \n";
    echo $help;
    exit(1);
}

if (!in_array($options['format'], $validformats, true)) {
    echo "ERROR: Invalid format '{$options['format']}' passed.\n";
    echo $help;
    exit(1);
}

$parsefunction = 'process_'.$options['format'];
if (!function_exists($parsefunction)) {
    echo "CODING ERROR: $parsefunction not found.\n";
    exit(1);
}



// Output begins, we always produce the preamble and checkstyle container.
$output = '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL .
'<checkstyle version="1.3.2">' . PHP_EOL;

while ($line = fgets(STDIN)) {
    $output.= $parsefunction($line);
}
$output .= '</checkstyle>';

echo $output;
exit;

/**
 * Converts grunt output into checkstyle format.
 *
 * Example input:
 *  GRUNT-CHANGE: /path/to/theme/bootstrapbase/style/moodle.css
 *
 * @param string $line the line of file
 * @return string the xml fragment
 */
function process_gruntdiff($line) {
    $output = '';
    // GRUNT-CHANGE: and ERROR: come from grunt_process.sh
    if (preg_match('/^GRUNT-CHANGE: (\S+)$/', $line, $matches)) {
        $filename = $matches[1];

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="0" column="0" severity="error" ';
        $output.= 'message="Uncommitted change detected."/>' . PHP_EOL;
        $output.= '</file>';
    } else if (preg_match('/^ERROR: (.*)$/', $line, $matches)) {
        $error = $matches[1];

        $output.= '<file name="">' . PHP_EOL;
        $output.= '<error line="0" column="0" severity="error" ';
        $output.= 'message="'. s($error) .'"/>' . PHP_EOL;
        $output.= '</file>';
    } else if (preg_match('/^Warning: (.*)$/', $line, $matches)) {
        // This is a warning coming directly from grunt output.
        $warning = $matches[1];

        $output.= '<file name="">' . PHP_EOL;
        $output.= '<error line="0" column="0" severity="warning" ';
        $output.= 'message="'. s($warning) .'"/>' . PHP_EOL;
        $output.= '</file>';
    }
    return $output;
}


/**
 * Converts phplint output into checkstyle format
 *
 * Example input:
 *   /path/to/install.php - ERROR: PHP Parse error: syntax error, unexpected '}' in /install.php on line 44
 *   /path/to/lib/adodb/adodb-lib.inc.php - OK
 *
 * @param string $line the line of file
 * @return string the xml fragment
 */
function process_phplint($line) {
    $output = '';

    if (preg_match('/^(\S+) \- ERROR: (.*)/', $line, $matches)) {
        $filename = $matches[1];
        $message = $matches[2];
        $lineno = 0;

        if (preg_match('/on line (\d+)/', $message, $matches) === 1) {
            // Only specify line number when exactly one detected in trace.
            $lineno = $matches[1];
        }

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="'.$lineno.'" column="0" severity="error" ';
        $output.= 'message="' .s($message). ' "/>' . PHP_EOL;
        $output.= '</file>';
    }

    return $output;
}

/**
 * Converts thirdparty output into checkstyle format
 *
 * Example input:
 *   /path/to/lib/markdown/Markdown.php - WARN: modification to third party library (lib/markdown) without update to lib/thirdpartylibs.xml or lib/markdown/readme_moodle.txt
 *
 * @param string $line the line of file
 * @return string the xml fragment
 */
function process_thirdparty($line) {
    $output = '';
    if (preg_match('/^(\S+) \- WARN: (.*)/', $line, $matches)) {
        $filename = $matches[1];
        $message = $matches[2];
        // FIXME: In the future it would be great to work out from the git-diff the line number and
        // be able to supply it here..
        $lineno = 0;

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="'.$lineno.'" column="0" severity="warning" ';
        $output.= 'message="' .s($message). ' "/>' . PHP_EOL;
        $output.= '</file>';
    }

    return $output;
}

/**
 * Converts shifter output into checkstyle format
 *
 * Example input:
 *   shifter [err] /path/to/lib/editor/atto/plugins/rtl/yui/src/button/js/button.js contains 2 lint errors
 *
 * @param string $line the line of file
 * @return string the xml fragment
 */
function process_shifter($line) {
    $output = '';
    if (preg_match('/shifter \[err\] (\S+) (.*)/', $line, $matches)) {
        $filename = $matches[1];
        $message = $matches[2];
        $lineno = 0;

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="'.$lineno.'" column="0" severity="error" ';
        $output.= 'message="' .s($message). ' "/>' . PHP_EOL;
        $output.= '</file>';
    }

    return $output;
}

/**
 * Converts mustachelint output into checkstyle format
 *
 * Example input:
 *  /path/to/linting.mustache - WARNING: HTML Validation error, line 2: End tag “p” seen, but there were open elements. (ello World</p></bo)"
 *  /path/to/linting.mustache - ERROR: Mustache syntax exception: Example context JSON is unparsable, fails with: Syntax error"
 *
 * @param string $line the line of file
 * @return string the xml fragment
 */
function process_mustachelint($line) {
    $output = '';

    if (preg_match('/^(\S+) \- (INFO|ERROR|WARNING): (.*)/', $line, $matches)) {
        $filename = $matches[1];
        $severity = strtolower($matches[2]);
        $message = $matches[3];
        $lineno = 1;

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="'.$lineno.'" column="0" severity="'.$severity.'" ';
        $output.= 'message="' .s($message). ' "/>' . PHP_EOL;
        $output.= '</file>';
    }

    return $output;
}

/**
 * Converts gherkin-lint json output into checkstyle format.
 *
 * @param string $line the line of file (in the case of json, it's everything into 1 line.
 * @return string the xml fragment
 */
function process_gherkinlint($line) {
    $output = '';
    $converted = json_decode($line);
    foreach ($converted as $file) {
        if (isset($file->errors) && !empty($file->errors)) {
            $output .= '<file name="' . $file->filePath . '">'.PHP_EOL;
            foreach ($file->errors as $error) {
                $output .= '<error line="' . $error->line . '" column="0" severity="error" ';
                $output .= 'source="' . s($error->rule) . '" message="' . s($error->message) . '" />' . PHP_EOL;
            }
            $output .= '</file>' . PHP_EOL;
        }
    }
    return $output;
}
