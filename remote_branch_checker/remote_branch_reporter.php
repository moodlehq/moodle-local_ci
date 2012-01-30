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
 * Unified reporting for all the remote_branch checks
 *
 * This script, given one directory with all the xml files resulting
 * from a remote_branch_checker execution, generates one unified
 * report in various formats, like:
 *   - xml: SMURF (simple moodle/mess universal reporting format)
 *   - txt
 *   - html
 *   - markdown
 *
 * @category   ci
 * @package    local_ci
 * @subpackage remote_branch_checker
 * @copyright  2012 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('NO_OUTPUT_BUFFERING', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions
require_once($CFG->dirroot.'/local/ci/remote_branch_checker/lib.php');

// now get cli options
list($options, $unrecognized) = cli_get_params(array(
                                                   'help'   => false,
                                                   'directory' => '',
                                                   'patchset' => false,
                                                   'format'   => ''),
                                               array(
                                                   'h' => 'help',
                                                   'd' => 'directory',
                                                   'p' => 'patchset',
                                                   'f' => 'format'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    $help =
"Generate one unified report for all the checks run by the remote_branch_checker

Options:
-h, --help            Print out this help
-d, --directory       Full path to the directory where all the check results are stored
-f, --filter          Patchset file name (@ directory) used to filter the problems
-f, --format          Select the output format (txt, html, xml, xunit), defaults to xml


Example:
\$sudo -u www-data /usr/bin/php local/ci/remote_branch_reporter.php directory=/tmp/results --format=txt
";

    echo $help;
    exit(0);
}

$directory = $options['directory'];
$format = $options['format'];
$patchset = $options['patchset'];

if (empty($directory) or empty($format)) {
    cli_error('Error: Always specify both directory and format');
}

raise_memory_limit(MEMORY_EXTRA);

$reporter = new remote_branch_reporter($directory);
$results = $reporter->run($format, $patchset);
echo $results;
