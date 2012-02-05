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
 * CLI utility in charge of generating (mock) build.xml ant files for package detection
 *
 * This script generates one Ant's build.xml file within each directory known to be the
 * base for one plugin/subplugin/subsystem. The generated simply contains one
 * project name tag that is used by all the qa tests to generate the information
 * grouped by packages. One cheap alternative to complex XLST transformations of
 * the source XML files. And common for all the qa tests.
 *
 * @package    core
 * @subpackage ci
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('NO_OUTPUT_BUFFERING', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions

// now get cli options
list($options, $unrecognized) = cli_get_params(array(
                                                   'help'   => false,
                                                   'basedir' => ''),
                                               array(
                                                   'h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    $help =
"Generate fake Ant's build.xml across code base for improved package
detection by CI QA tests (cpd, check, mess, todo...)  using built-in Moodle plugin/subsystem facilities.

Options:
-h, --help            Print out this help
--basedir             Full path to the moodle base dir to fill with build.xml files

Example:
\$sudo -u www-data /usr/bin/php local/ci/generate_component_ant_files/generate_component_ant_files.php --basedir=/home/moodle/git
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

 Get all the plugin and subplugin types
$types = get_plugin_types(false);
// For each type, get their available implementations
foreach ($types as $type => $typerelpath) {
    $plugins = get_plugin_list($type);
    // For each plugin, let's calculate the proper component name and generate
    // the corresponding build.xml file
    foreach ($plugins as $plugin => $pluginabspath) {
        $component = $type . '_' . $plugin;
        $directory = $options['basedir'] . '/' . $typerelpath . '/' . $plugin;
        echo "Creating $directory/build.xml for $component" . PHP_EOL;
        create_ant_build_xml_file($component, $directory);
    }
}

// Get all the subsystems and
// generate the corresponding build.xml file
$subsystems = get_core_subsystems();
$subsystems['core'] = '.'; // To get the main one too
foreach ($subsystems as $subsystem => $subsystemrelpath) {
    if (empty($subsystemrelpath)) {
        continue;
    }
    if ($subsystem == 'backup') { // Because I want, yes :-P
        $subsystemrelpath = 'backup';
    }
    $component = $subsystem;
    $directory = $options['basedir'] . '/' . $subsystemrelpath;
    echo "Creating $directory/build.xml for $component" . PHP_EOL;
    create_ant_build_xml_file($component, $directory);
}

/**
 * Build the fake Ant's build.xml file containing good component names
 */
function create_ant_build_xml_file($component, $directory) {
    $file = $directory . '/build.xml';
    if (file_exists($directory)) {
        if (file_exists($file)) {
            unlink($file);
        }
        if (!file_exists($file)) {
            $contents = '<project name="' . $component . '" basedir="."/>';
            file_put_contents($directory . '/' . 'build.xml', $contents);
        }
    }
}
