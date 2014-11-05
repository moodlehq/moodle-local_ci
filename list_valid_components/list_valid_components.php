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

require_once('clilib.php');      // cli only functions

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
\$sudo -u www-data /usr/bin/php local/ci/list_valid_components/list_valid_components.php --basedir=/home/moodle/git --absoulte=false
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

// For Moodle 2.6 and upwards, we execute this specific code that does not require
// the site to be installed (relying on new classes only available since then).
if (file_exists($options['basedir'] . '/lib/classes/component.php')) {
    define('IGNORE_COMPONENT_CACHE', 1);
    define('MOODLE_INTERNAL', 1);
    unset($CFG);
    global $CFG;
    $CFG = new stdClass();
    $CFG->dirroot = $options['basedir'];
    $CFG->libdir = $CFG->dirroot . '/lib';
    $CFG->admin = 'admin';
    require_once($CFG->dirroot . '/lib/classes/component.php');

    // Get all the plugins and subplugin types.
    $types = core_component::get_plugin_types();
    // Sort types in reverse order, so we get subplugins earlier than plugins.
    $types = array_reverse($types);
    // For each type, get their available implementations.
    foreach ($types as $type => $fullpath) {
        $plugins = core_component::get_plugin_list($type);
        // For each plugin, let's calculate the proper component name and output it.
        foreach ($plugins as $plugin => $pluginpath) {
            $component = $type . '_' . $plugin;
            if (!$options['absolute']) {
                $pluginpath = str_replace($options['basedir'] . '/', '', $pluginpath);
            }
            echo 'plugin,' . $component . ',' . $pluginpath . PHP_EOL;
        }
    }

    // Get all the subsystems.
    $subsystems = core_component::get_core_subsystems();
    $subsystems['core'] = $options['basedir']; // To get the main one too
    foreach ($subsystems as $subsystem => $subsystempath) {
        if ($subsystem == 'backup') { // Because I want, yes :-P
            $subsystempath = $options['basedir'] . '/backup';
        }
        // All subsystems are core_ prefixed.
        $component = 'core_' . $subsystem;
        if ($subsystem === 'core') { // But core.
            $component = 'core';
        }
        if (!$options['absolute'] and !empty($subsystempath)) {
            $subsystempath = str_replace($options['basedir'] . '/', '', $subsystempath);
        }
        echo 'subsystem,' . $component . ',' . $subsystempath . PHP_EOL;
    }
    // We are done, end here.
    exit(0);
}

// Up to Moodle 2.5, we use the old global API, that requires the site to be installed
// (the shell script calling this handles those reqs automatically)
// TODO: Once 2.5 is out we can change this by the new core_component::get_xxx() calls.
// until then will be using the deprecated ones.
require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');

// Get all the plugin and subplugin types
$types = get_plugin_types(true);
// Sort types in reverse order, so we get subplugins earlier than plugins
$types = array_reverse($types);
// For each type, get their available implementations
foreach ($types as $type => $fullpath) {
    $plugins = get_plugin_list($type);
    // For each plugin, let's calculate the proper component name and generate
    // the corresponding build.xml file
    foreach ($plugins as $plugin => $pluginpath) {
        $component = $type . '_' . $plugin;
        if (!$options['absolute']) {
            // Want relatives, clean dirroot.
            $pluginpath = str_replace($CFG->dirroot . '/', '', $pluginpath);
        } else {
            // Want absolutes, replace dirroot by basedir.
            $pluginpath = str_replace($CFG->dirroot, $options['basedir'] , $pluginpath);
        }
        echo 'plugin,' . $component . ',' . $pluginpath . PHP_EOL;
    }
}

// Get all the subsystems and
// generate the corresponding build.xml file
$subsystems = get_core_subsystems(true);
$subsystems['core'] = $options['basedir']; // To get the main one too
foreach ($subsystems as $subsystem => $subsystempath) {
    if ($subsystem == 'backup') { // Because I want, yes :-P
        $subsystempath = $options['basedir'] . '/backup';
    }
    // All subsystems are core_ prefixed.
    $component = 'core_' . $subsystem;
    if ($subsystem === 'core') { // But core.
        $component = 'core';
    }
    // If it's a subsystem with path.
    if (!empty($subsystempath)) {
        if (!$options['absolute']) {
            // Want relatives, clean dirroot.
            $subsystempath = str_replace($CFG->dirroot . '/', '', $subsystempath);
        } else {
            // Want absolutes, replace dirroot by basedir.
            $subsystempath = str_replace($CFG->dirroot, $options['basedir'], $subsystempath);
        }
    }
    echo 'subsystem,' . $component . ',' . $subsystempath . PHP_EOL;
}
