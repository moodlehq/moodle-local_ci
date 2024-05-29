<?php
// This file is part of Moodle - https://moodle.org/
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
// along with Moodle.  If not, see <https://www.gnu.org/licenses/>.

/**
 * CLI utility in charge of creating the main phpunit.xml file for further inspections.
 *
 * For a given, valid, Moodle's root directory (dirroot), this will generate
 * the phpunit.xml, normally used by phpunit runs. The main difference is that it's
 * done in a way a real site and database are not needed, so it's quicker and easier
 * to run in any environment (very similar to list_valid_components job).
 *
 * @category   test
 * @package    local_ci
 * @subpackage remote_branch_checker
 * @copyright  2022 onwards Eloy Lafuente (stronk7) {@link https://stronk7.com}
 * @license    https://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

require_once(__DIR__.'/../phplib/clilib.php');

// now get cli options
list($options, $unrecognized) = cli_get_params(
    [
        'help'   => false,
        'basedir' => '',
    ],
    [
        'h' => 'help',
        'b' => 'basedir',
    ]
);

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$unrecognized}\n Please use --help option.");
}

if ($options['help']) {
    $help =
"Generate the phpunit.xml file for a given Moodle's root directory.

Options:
-h, --help            Print out this help.
--basedir             Full path to the moodle base dir to look for components.

Example:
php local/ci/verify_phpunit_xml/create_phpunit_xml.php --basedir=/home/moodle/git
";

    echo $help;
    exit(0);
}

if (empty($options['basedir'])) {
    cli_error('Missing basedir param. Please use --help option.');
}
if (!file_exists($options['basedir'])) {
    cli_error('Incorrect directory: ' . $options['basedir']);
}
if (!is_writable($options['basedir'])) {
    cli_error('Non-writable directory: ' . $options['basedir']);
}

// We need all the components loaded first.
if (!load_core_component_from_moodle($options['basedir'])) {
    cli_error('Something went wrong. Components not loaded from ' . $options['basedir']);
}

// We need to register the Moodle autoloader.
require_once($options['basedir'] . '/lib/classes/component.php');
spl_autoload_register([\core_component::class, 'classloader']);

// Now, let's invoke phpunit utils to generate the phpunit.xml file

// We need to load a few stuff.
require_once($options['basedir'] . '/lib/phpunit/classes/util.php');
require_once($options['basedir'] . '/lib/outputcomponents.php');
require_once($options['basedir'] . '/lib/testing/lib.php');
phpunit_util::build_config_file();

// We are done, end here.
exit(0);
