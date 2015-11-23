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
 * Convert grunt_process Unbuilt changes .txt files to checkstyle xml format
 *
 * This script will convert the (textual) output from
 * the grunt_process to one checkstyle-like xml formal
 * for easier integration in other CI tools/reports. It's used by
 * some jobs like the remote_branch_checker one.
 *
 * @category   ci
 * @package    local_ci
 * @subpackage grunt_process
 * @copyright  2015 Dan Poltawski
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('NO_OUTPUT_BUFFERING', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions

// now get cli options
list($options, $unrecognized) = cli_get_params(
    array('help' => false),
    array('h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    $help =
"Convert grunt_process text output to checkstyle xml format

Options:
-h, --help            Print out this help

Example:
\$sudo -u www-data /usr/bin/php local/ci/grunt_process/gruntprocess2checkstyle.php < file.txt > file.xml
";
    echo $help;
    exit(0);
}

// Output begins, we always produce the preamble and checkstyle container.
$output = '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL .
'<checkstyle version="1.3.2">' . PHP_EOL;

while ($line = fgets(STDIN)) {
    if (preg_match('/^GRUNT-CHANGE: (\S+)$/', $line, $matches)) {
        $filename = $matches[1];

        $output.= '<file name="' . $filename. '">'.PHP_EOL;
        $output.= '<error line="0" column="0" severity="error" ';
        $output.= 'message="Un-built change detected."/>' . PHP_EOL;
        $output.= '</file>';
    }
}
$output .= '</checkstyle>';

echo $output;
