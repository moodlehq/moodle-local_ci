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
 * Convert verify_commit_messages .txt files to checkstyle xml format
 *
 * This script will convert the (textual) output from
 * the verify_commit_messages to one checkstyle-like xml formal
 * for easier integration in other CI tools/reports. It's used by
 * some jobs like the remote_branch_checker one.
 *
 * @category   ci
 * @package    local_ci
 * @subpackage verify_commit_messages
 * @copyright  2014 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

require_once(__DIR__.'/../phplib/clilib.php');

// now get cli options
list($options, $unrecognized) = cli_get_params(
    array('help' => false),
    array('h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$Unrecognised}\n Please use --help option.");

}

if ($options['help']) {
    $help =
"Convert verify_commit_messages text output to checkstyle xml format

Options:
-h, --help            Print out this help

Example:
\$sudo -u www-data /usr/bin/php local/ci/verify_commit_messages/commits2checkstyle.php < file.txt > file.xml
";
    echo $help;
    exit(0);
}

// Let's process the $reporttxt contents, annotating all errors and warnings into checkstyle xml format
$output = '';
$ccommit   = '';
$cseverity = '';
$cmessage = '';
$lastcommit = '';

// Output begins, we always produce the preamble and checkstyle container.
$output .= '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL .
'<checkstyle version="1.3.2">' . PHP_EOL;

while ($line = trim(fgets(STDIN))) {
    if (trim($line) === '') {
        continue;
    }
    if (preg_match('/^([0-9a-f]{7,16}|.*\.\.\..*)\*(info|error|warning)\*(.*)$/', $line, $matches) === 0) {
        cli_error('Error: Unexpected format found: "' . $line . '"');
    }
    // Arrived here, we have a correct line.
    $ccommit = $matches[1];
    $cseverity = $matches[2];
    $cmessage = $matches[3];

    // Severity found, output xml
    if (!empty($cseverity)) {
        // Change of commit.
        if ($ccommit !== $lastcommit) {
            if ( $lastcommit !== '') {
                $output .= '  </file>' . PHP_EOL;
            }
            $output .= '  <file name="' . $ccommit . '">' . PHP_EOL;
        }
        // Use line and column 0, we don't really know the real line in the original format
        $output .= '    <error line="0" column="0" severity="' . $cseverity . '" message="' .
            s($cmessage) . ' "/>' . PHP_EOL;
    }
    $lastcommit = $ccommit;
}
if ($ccommit) { // There is a commit (aka, file) pending to close.
    $output .= '  </file>' . PHP_EOL;
}
$output .= '</checkstyle>';

echo $output;
