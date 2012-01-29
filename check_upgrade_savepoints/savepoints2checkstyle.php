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
 * Convert check_upgrade_savepoints .txt files to checkstyle xml format
 *
 * This script will convert the (textual) output from
 * the check_upgrade_savepoints to one checkstyle-like xml formal
 * for easier integration in other CI tools/reports. It's used by
 * some jobs like the remote_branch_checker one.
 *
 * @category   ci
 * @package    local_ci
 * @subpackage check_upgrade_savepoints
 * @copyright  2012 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('NO_OUTPUT_BUFFERING', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions

// look for any piped content
stream_set_blocking(STDIN, 0);
$reporttxt = stream_get_contents(STDIN);

// if there are contents, file is not necessary

// now get cli options
list($options, $unrecognized) = cli_get_params(
    array('help' => false),
    array('h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if (empty($reporttxt)) {
    exit(0);
}

$reportarr = preg_split('/(\r?\n)/', $reporttxt);
if (strpos($reportarr[0], '  - ') !== 0 or strpos($reportarr[1], '    + ') !== 0) {
    cli_error('Error: Input file does not seem to be a check_upgrade_savepoints.txt one');
}

if ($options['help']) {
    $help =
"Convert check_upgrade_savepoints text output to checkstyle xml format

Options:
-h, --help            Print out this help

Example:
\$sudo -u www-data /usr/bin/php local/ci/check_upgrade_savepoints/savepoints2checkstyle.php < file.txt > file.xml
";
    echo $help;
    exit(0);
}

// Let's process the $reporttxt contents, annotating all errors and warnings into checkstyle xml format
$output = '';
$cfile   = '';
$cseverity = '';
foreach ($reportarr as $line) {
    // If it's a file description, save it
    if (strpos($line, '  - ') === 0) {
        $cfile = preg_replace('/^  - (.*):\s*$/', '$1', $line);
    }
    // If it's an error or warning, grab severity
    if (strpos($line, '    + ERROR') === 0) {
        $cseverity = 'error';
    } else if (strpos($line, '    + WARN') === 0) {
        $cseverity = 'warning';
    } else {
        $cseverity = '';
    }
    // Severity found, output xml
    if (!empty($cseverity)) {
        // no output, yet, send XML preamble and root element
        if (empty($output)) {
            $output .= '<?xml version="1.0" encoding="UTF-8"?>' . PHP_EOL .
                '<checkstyle version="1.3.2">' . PHP_EOL;
        }
        $output .= '  <file name="' . $cfile . '">' . PHP_EOL;
        // Use line and column 0, we don't really know the real line in the original format
        $output .= '    <error line="0" column="0" severity="' . $cseverity . '" message="' .
            trim(preg_replace('/^    \+ (ERROR|WARN):(.*)$/', '$2', $line)) . ' "/>' . PHP_EOL;
        $output .= '  </file>' . PHP_EOL;
    }
}
// output exists, close root element
if (!empty($output)) {
    $output .= '</checkstyle>';
}
echo $output;
