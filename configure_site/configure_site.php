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
 * CLI configuration (file/database) tool
 *
 * This script accepts target,name/value pairs to set any configuration
 * setting both in the config.php file (write-perm required) and/or the
 * config and config_plugin tables.
 * It support configurations to be specified as params (1 by 1) and also
 * to be batch-loaded and applied from a configuration file in the presets
 * subdir
 *
 * Format of any configuration option is, always:
 *     target, type, name[:plugin][, value]
 * With:
 *     target: file (config.php) or db (config/config_plugin tables)
 *     type: add (to add) ot del (to delete)
 *     name: the name of the configuration setting (debug,...)
 *     component: optional, the name of the component the setting belongs to (forum, auth_manual...)
 *     value: the configuration value (only on add rules).
 *
 * @category   ci
 * @package    local_ci
 * @subpackage configure_site
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions
require_once($CFG->dirroot.'/local/ci/configure_site/lib.php');

// now get cli options
list($options, $unrecognized) = cli_get_params(array(
                                                   'help'   => false,
                                                   'rule'   => '',
                                                   'preset' => ''),
                                               array(
                                                   'h' => 'help',
                                                   'r' => 'rule',
                                                   'p' => 'preset'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    $help =
"Set various configuration options for a given site, both @ config.php and database

Options:
-h, --help            Print out this help
-r, --rule            Define the configuration option to apply
-p, --preset          Define the preset (batch of rules) to apply

Format of any configuration option is, always:
    target, type, name[:plugin][, value]
With:
    target: file (config.php) or db (config/config_plugin tables)
    type: add (to add) or del (to delete)
    name: the name of the configuration setting (debug,...)
    component: optional, the name of the component the setting belongs to (forum, auth_manual...)
    value: the configuration value (only on add rules).

Example:
\$sudo -u www-data /usr/bin/php admin/cli/configure_site/configure_site.php --rule=file,add,debug,38911
";

    echo $help;
    exit(0);
}

$rule = $options['rule'];
$preset= $options['preset'];

if (empty($rule) && empty($preset)) {
    cli_error('Both --rule and --preset missing. Use --help to get more info.');
}

if (!empty($rule) && !empty($preset)) {
    cli_error('Both --rule and --preset cannot be specified together. Use --help to get more info.');
}

// Load the rules
if ($rule) {
    $rules = array(explode(',', $rule));
} else {
    if (!$rules = confsite_load_rules($preset)) {
        cli_error("Problem loading rules for preset: $preset");
    }
}

// Verify the rules
if ($errors = confsite_verify_rules($rules)) {
    cli_error(reset($errors));
}

// Apply the rules
if ($errors = confsite_apply_rules($rules)) {
    cli_error(reset($errors));
}
