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
 * Library of classes/functions for configure_site
 *
 * @category   ci
 * @package    local_ci
 * @subpackage configure_site
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

/**
 * Load one preset from the presets directory
 */
function confsite_load_rules($preset) {
    global $CFG;

    $rules = array();

    if (strpos($preset, '.txt') === false) {
        $preset .= '.txt';
    }

    $presetfile = $CFG->dirroot.'/'.$CFG->admin.'/ci/configure_site/presets/'.$preset;
    if (!file_exists($presetfile) || !is_readable($presetfile)) {
        return;
    }
    if (($fh = fopen($presetfile, 'r')) === false) {
        return;
    }
    while (($line = fgetcsv($fh, null, ',')) !== false) {
        $rules[] = $line;
    }
    fclose($fh);

    return $rules;
}

/**
 * Verify one array of rules, returns array of errors
 */
function confsite_verify_rules($rules) {
    foreach ($rules as $key => $rule) {
        $ruledef = "#" . ($key + 1) . ' (' . implode(',', $rule) . ')';

        // target must be 'file' or 'db'
        if (trim($rule[0]) != 'file' && trim($rule[0]) != 'db') {
            return array("Rule {$ruledef} incorrect. Target element must be 'file' or 'db'");
        }

        // type must be 'add' or 'del'
        if (trim($rule[1]) != 'add' && trim($rule[1]) != 'del') {
            return array("Rule {$ruledef} incorrect. Type element must be 'add' or 'del'");
        }

        // split name and component if present
        $name = trim($rule[2], ": \t\n\r");
        $component = '';
        if (($seppos = strpos($name, ':')) !== false) {
            $component = substr($name, $seppos + 1);
            $name = substr($name, 0, $seppos);
        }

        // name must be alphanum
        if ($name !== clean_param($name, PARAM_ALPHANUMEXT)) {
            return array("Rule {$ruledef} incorrect. Name element must be PARAM_ALPHANUMEXT");
        }

        // if present, verify the component is valid
        if ($component && $component !== clean_param($component, PARAM_COMPONENT)) {
            return array("Rule {$ruledef} incorrect. Component element must be PARAM_COMPONENT");
        }

        // components are only allowed for 'db' target
        if ($component && trim($rule[0]) == 'file') {
            return array("Rule {$ruledef} incorrect. Component only allowed for 'db' targets");
        }

        // verify 'value' is set for 'add' rules
        if (trim($rule[1]) == 'add' && !isset($rule[3])) {
            return array("Rule {$ruledef} incorrect. Values are mandatory to rules of type 'add'");
        }

        // verify 'value' is not set for 'del' rules
        if (trim($rule[1]) == 'del' && isset($rule[3])) {
            return array("Rule {$ruledef} incorrect. Values are forbidden to rules of type 'del'");
        }
    }
    return array();
}

/**
 * Apply rules, delegating to confsite_apply_file|db_rule()
 */
function confsite_apply_rules($rules) {
    foreach($rules as $key => $rule) {
        $ruledef = "#" . ($key + 1) . ' (' . implode(',', $rule) . ')';
        echo "Processing rule {$ruledef}...";
        if (trim($rule[0]) == 'file') {
            $error = confsite_apply_file_rule($rule);
        } else {
            $error = confsite_apply_db_rule($rule);
        }
        if ($error) {
            echo "ERROR\n";
            return $error;
        } else {
            echo "OK\n";
        }
    }
}

/**
 * Apply one file (config.php)
 * @todo Implement this
 */
function confsite_apply_file_rule($rule) {
    $ruledef = '(' . implode(',', $rule) . ')';
    return array("Rule {$ruledef}, of type 'file' not implemented yet. Sorry.");
}

/**
 * Apply one db (config/config_plugin tables) rule
 */
function confsite_apply_db_rule($rule) {
    global $DFG, $DB;

    $ruledef = '(' . implode(',', $rule) . ')';

    $type = trim($rule[1]);
    $value = $type == 'add' ? trim($rule[3]) : null;
    // split name and component if present
    $name = trim($rule[2], ": \t\n\r");
    $component = '';
    if (($seppos = strpos($name, ':')) !== false) {
        $component = substr($name, $seppos + 1);
        $name = substr($name, 0, $seppos);
    }
    if ($type = 'add') {
        set_config($name, $value, $component);
    } else {
        unset_config($name, $component);
    }
    return array();
}
