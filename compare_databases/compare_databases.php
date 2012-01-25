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
 * CLI DB comparison utility useful for automated CI jobs
 *
 * This script compares (using own Moodle DB schema facilitites) two DBs
 * reporting any difference found between them. Useful to build some CI jobs
 * on top of it.
 *
 * TODO: Some day, allow to specify different library/type for comparison,
 *       simply has not been implemented for now because it's ok for our CI purposes
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
                                                   'dblibrary' => 'native',
                                                   'dbtype'  => 'mysqli',
                                                   'dbhost1'   => 'localhost',
                                                   'dbhost2'   => '',
                                                   'dbuser1'   => '',
                                                   'dbuser2'   => '',
                                                   'dbpass1'   => '',
                                                   'dbpass2'   => '',
                                                   'dbname1'   => '',
                                                   'dbname2'   => '',
                                                   'dbprefix1' => 'mdl_',
                                                   'dbprefix2' => ''),
                                               array(
                                                   'h' => 'help'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if (empty($options['dblibrary']) || empty($options['dbtype']) || empty($options['dbhost1']) ||
    empty($options['dbuser1']) || empty($options['dbpass1']) || empty($options['dbname1']) ||
    empty($options['dbprefix1'])) {

    cli_error('Missing dblibrary/dbtype/dbhost1/dbuser1/dbpass1/dbname1/dbprefix1 param. Please use --help option.');
}

$options['dbhost2'] = empty($options['dbhost2']) ? $options['dbhost1'] : $options['dbhost2'];
$options['dbuser2'] = empty($options['dbuser2']) ? $options['dbuser1'] : $options['dbuser2'];
$options['dbpass2'] = empty($options['dbpass2']) ? $options['dbpass1'] : $options['dbpass2'];
$options['dbname2'] = empty($options['dbname2']) ? $options['dbname1'] : $options['dbname2'];
$options['dbprefix2'] = empty($options['dbprefix2']) ? $options['dbprefix1'] : $options['dbprefix2'];

if ($options['help']) {
    $help =
"Compare 2 database schemas, using built-in Moodle facilities

Options:
-h, --help            Print out this help
--
--dblibrary           Type of PHP driver used (native, pdo..). Defaults to native
--dbtype              Name of the driver used (mysqli, pqsql...). Defaults to mysqli
--dbhostX             IP/Name of the host. Defaults to localhost, 2nd defaults to 1st
--dbuserX             Login to the database. 2nd defaults to 1st
--dbpassX             Password to the database. 2nd defaults to 1st
--dbnameX             Name of the database. 2nd defaults to 1st
--dbprefixX           Prefix to apply to all DB objects. Defaults to mdl. 2nd defaults to 1st

Example:
\$sudo -u www-data /usr/bin/php admin/ci/compare_databases/compare_databases.php --dbuser1=stronk7 --dbpass1=mojitos --dbname1=dbone --dbname2=dbtwo
";

    echo $help;
    exit(0);
}

// Always run the comparison in developer debug mode.
$CFG->debug = DEBUG_DEVELOPER;
error_reporting($CFG->debug);
raise_memory_limit(MEMORY_EXTRA);

// Let's connect to both ends
$db1 = compare_connect($options['dblibrary'], $options['dbtype'], $options['dbhost1'], $options['dbuser1'],
                       $options['dbpass1'], $options['dbname1'], $options['dbprefix1']);
$db2 = compare_connect($options['dblibrary'], $options['dbtype'], $options['dbhost2'], $options['dbuser2'],
                       $options['dbpass2'], $options['dbname2'], $options['dbprefix2']);

list($tablesarr, $errorsarr) = compare_tables($db1, $db2);

foreach ($tablesarr as $tname => $tinfo) {
    $errorsarr = array_merge($errorsarr, compare_columns($tname, $tinfo->columns1, $tinfo->columns2));
    $errorsarr = array_merge($errorsarr, compare_indexes($tname, $tinfo->indexes1, $tinfo->indexes2));
}

// Errors found, print them
$nerrors = count($errorsarr);
if ($errorsarr) {
    // Prepare params
    ksort($options);
    $paramstxt = '  Parameters: ';
    foreach ($options as $key => $value) {
        if ($key == 'dbpass1' || $key == 'dbpass2' || $key == 'help') {
            continue;
        }
        $paramstxt .= "{$key}={$value}, ";
    }
    $paramstxt = substr($paramstxt, 0, -2);
    echo "Problems found comparing databases!" . PHP_EOL;
    echo $paramstxt . PHP_EOL;
    echo "  Number of errors: {$nerrors}" . PHP_EOL;
    echo PHP_EOL;
    foreach ($errorsarr as $error) {
        echo "  {$error}" . PHP_EOL;
    }
}
exit(empty($nerrors) ? 0 : 1);

// SOME useful functions go here

function compare_beautify($val) {
    if ($val === null) {
        return 'null';
    }
    if ($val === true) {
        return 'true';
    }
    if ($val === false) {
        return 'false';
    }
    return $val;
}

function compare_column_specs($tname, $cname, $specs1, $specs2) {
    $errors = array();

    // Take out all the elements in the specs not defined in both sides
    foreach ($specs1 as $key => $value) {
        if (!array_key_exists($key, $specs2)) {
            unset($specs1[$key]);
        }
    }
    foreach ($specs2 as $key => $value) {
        if (!array_key_exists($key, $specs1)) {
            unset($specs2[$key]);
        }
    }
    // Now strict compare the existing specs
    foreach ($specs1 as $key => $value) {
        if ($specs1[$key] !== $specs2[$key]) {
            $val1 = compare_beautify($specs1[$key]);
            $val2 = compare_beautify($specs2[$key]);
            $errors[] = "Column {$cname} of table {$tname} difference found in {$key}: {$val1} !== {$val2}";
        }
    }
    return $errors;
}

function compare_columns($tname, $info1, $info2) {
    $errors = array();

    foreach ($info1 as $cname => $cvalue) {
        if (!isset($info2[$cname])) {
            $errors[] = "Column {$cname} of table {$tname} only available in first DB";
            unset($info1[$cname]);
        }
    }

    foreach ($info2 as $cname => $cvalue) {
        if (!isset($info1[$cname])) {
            $errors[] = "Column {$cname} of table {$tname} only available in second DB";
            unset($info2[$cname]);
        }
    }

    // For the remaining elements, compare specs
    foreach ($info1 as $cname => $cvalue) {
        $errors = array_merge($errors, compare_column_specs($tname, $cname, (array)$cvalue, (array)$info2[$cname]));
    }
    return $errors;
}

function compare_indexes($tname, $info1, $info2) {
    $ninfo1 = array();
    $ninfo2 = array();
    $errors = array();

    // Normalize info (we ignore index names)
    foreach ($info1 as $iname => $ivalue) {
        $ikey = implode('-', $ivalue['columns']);
        $ninfo1[$ikey] = $ivalue;
    }
    foreach ($info2 as $iname => $ivalue) {
        $ikey = implode('-', $ivalue['columns']);
        $ninfo2[$ikey] = $ivalue;
    }

    foreach ($ninfo1 as $iname => $ivalue) {
        if (!isset($ninfo2[$iname])) {
            $ikey = implode('-', $ivalue['columns']);
            $errors[] = "Index ({$ikey}) of table {$tname} only available in first DB";
            unset($ninfo1[$iname]);
        }
    }

    foreach ($ninfo2 as $iname => $ivalue) {
        if (!isset($ninfo1[$iname])) {
            $ikey = implode('-', $ivalue['columns']);
            $errors[] = "Index ({$ikey}) of table {$tname} only available in second DB";
            unset($ninfo2[$iname]);
        }
    }

    // For the remaining elements, compare specs (only unique needed)
    foreach ($ninfo1 as $iname => $ivalue) {
        if ($ivalue['unique'] !== $ninfo2[$iname]['unique']) {
            $val1 = compare_beautify($ivalue['unique']);
            $val2 = compare_beautify($ninfo2[$iname]['unique']);
            $ikey = implode('-', $ivalue['columns']);
            $errors[] = "Index ({$ikey}) of table {$tname} difference found in unique: {$val1} !== {$val2}";
        }
    }
    return $errors;
}

function compare_tables($db1, $db2) {
    $tocompare = array();
    $errors    = array();

    $tables1 = $db1->get_tables();
    $tables2 = $db2->get_tables();

    foreach ($tables1 as $tname => $tvalue) {
        if (isset($tables2[$tname])) {
            $tocompare[$tname] = new stdClass();
            unset($tables2[$tname]);
        } else {
            $errors[] = "Table {$tname} only available in first DB";
        }
        unset($tables1[$tname]);
    }

    foreach ($tables2 as $tname => $tvalue) {
        $errors[] = "Table {$tname} only available in second DB";
        unset($tables2[$tname]);
    }

    foreach ($tocompare as $tname => $element) {
        $element->columns1 = $db1->get_columns($tname);
        $element->indexes1 = $db1->get_indexes($tname);
        $element->columns2 = $db2->get_columns($tname);
        $element->indexes2 = $db2->get_indexes($tname);
    }
    return array($tocompare, $errors);
}


function compare_connect($library, $type, $host, $user, $pass, $name, $prefix) {
    global $CFG;

    $classname = "{$type}_{$library}_moodle_database";
    if (!file_exists("$CFG->libdir/dml/$classname.php")) {
        cli_error("Error connecting to DB: Driver {$classname} not available");
    }
    require_once("$CFG->libdir/dml/$classname.php");
    $DB = new $classname();
    if (!$DB->driver_installed()) {
        cli_error("Error connecting to DB: PHP driver for {$classname} not installed");
    }
    try {
        $DB->connect($host, $user, $pass, $name, $prefix, array());
    } catch (dml_connection_exception $e) {
        cli_error("Error connecting to DB: Cannot connect to {$name}");
    }
    return $DB;
}
