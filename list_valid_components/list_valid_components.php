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
 * CLI utility in charge of listing all the available components for a given directory
 *
 * For a given, valid, Moodle's root directory (dirroot), return the type, name and
 * path (absolute or relative) of all the components (plugins and subsystems) available.
 *
 * Returned information will have the format (comma separated):
 *     type (plugin, subsystem)
 *     name (frankestyle component name)
 *     path (absolute, relative or null)
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

// now get cli options
list($options, $unrecognized) = cli_get_params(array(
                                                   'help'   => false,
                                                   'basedir' => '',
                                                   'absolute'=> 'true'),
                                               array(
                                                   'h' => 'help',
                                                   'b' => 'basedir',
                                                   'a' => 'absolute'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    $help =
"Generate a list of valid components for a given Moodle's root directory.

Options:
-h, --help            Print out this help.
--basedir             Full path to the moodle base dir to look for components.
--absolute            Return absolute (true, default) or relative (false) paths.

Example:
\$sudo -u www-data /usr/bin/php local/ci/remote_branch_checker/list_valid_components.php --basedir=/home/moodle/git --absoulte=false
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

if ($options['absolute'] == 'true') {
    $options['absolute'] = true;
} else if ($options['absolute'] == 'false') {
    $options['absolute'] = false;
}

if (!is_bool($options['absolute'])) {
    cli_error('Incorrect absolute value, bool expected: ' . $options['absolute']);
}

// Let's fake dirroot to look in the correct directory
global $CFG;
$olddirroot = $CFG->dirroot;
$CFG->dirroot = $options['basedir'];

// Get all the plugin and subplugin types
$types = get_plugin_types(false);
// Sort types in reverse order, so we get subplugins earlier than plugins
$types = array_reverse($types);
// For each type, get their available implementations
foreach ($types as $type => $typerelpath) {
    $plugins = get_plugin_list($type);
    // For each plugin, let's calculate the proper component name and generate
    // the corresponding build.xml file
    foreach ($plugins as $plugin => $pluginpath) {
        $component = $type . '_' . $plugin;
        if (!$options['absolute']) {
            $pluginpath = str_replace($options['basedir'] . '/', '', $pluginpath);
        }
        echo 'plugin,' . $component . ',' . $pluginpath . PHP_EOL;
    }
}

// Get all the subsystems and
// generate the corresponding build.xml file
$subsystems = get_core_subsystems();
$subsystems['core'] = '.'; // To get the main one too
foreach ($subsystems as $subsystem => $subsystempath) {
    if ($subsystem == 'backup') { // Because I want, yes :-P
        $subsystempath = 'backup';
    }
    $component = $subsystem;
    if ($options['absolute'] and !empty($subsystempath)) {
        $subsystempath = $options['basedir'] . '/' . $subsystempath;
    }
    echo 'subsystem,' . $subsystem . ',' . $subsystempath . PHP_EOL;
}

// Return to real dirroot
$CFG->dirroot = $olddirroot;
