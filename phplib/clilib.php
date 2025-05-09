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
 * Command line utility functions and classes
 *
 * @package    core
 * @subpackage cli
 * @copyright  2009 Petr Skoda (http://skodak.org)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

/**
 * Write a text to the given stream
 *
 * @param string $text text to be written
 * @param resource $stream output stream to be written to, defaults to STDOUT
 */
function cli_write($text, $stream=STDOUT) {
    fwrite($stream, $text);
}

/**
 * Write a text followed by an end of line symbol to the given stream
 *
 * @param string $text text to be written
 * @param resource $stream output stream to be written to, defaults to STDOUT
 */
function cli_writeln($text, $stream=STDOUT) {
    cli_write($text.PHP_EOL, $stream);
}

/**
 * Get input from user
 * @param string $prompt text prompt, should include possible options
 * @param string $default default value when enter pressed
 * @param array $options list of allowed options, empty means any text
 * @param bool $casesensitive true if options are case sensitive
 * @return string entered text
 */
function cli_input($prompt, $default='', array $options=null, $casesensitiveoptions=false) {
    cli_writeln($prompt);
    cli_write(': ');
    $input = fread(STDIN, 2048);
    $input = trim($input);
    if ($input === '') {
        $input = $default;
    }
    if ($options) {
        if (!$casesensitiveoptions) {
            $input = strtolower($input);
        }
        if (!in_array($input, $options)) {
            cli_writeln('Incorrect value, please retry');
            return cli_input($prompt, $default, $options, $casesensitiveoptions);
        }
    }
    return $input;
}

/**
 * Returns cli script parameters.
 * @param array $longoptions array of --style options ex:('verbose'=>false)
 * @param array $shortmapping array describing mapping of short to long style options ex:('h'=>'help', 'v'=>'verbose')
 * @return array array of arrays, options, unrecognised as optionlongname=>value
 */
function cli_get_params(array $longoptions, array $shortmapping=null) {
    $shortmapping = (array)$shortmapping;
    $options      = array();
    $unrecognized = array();

    if (empty($_SERVER['argv'])) {
        // bad luck, we can continue in interactive mode ;-)
        return array($options, $unrecognized);
    }
    $rawoptions = $_SERVER['argv'];

    //remove anything after '--', options can not be there
    if (($key = array_search('--', $rawoptions)) !== false) {
        $rawoptions = array_slice($rawoptions, 0, $key);
    }

    //remove script
    unset($rawoptions[0]);
    foreach ($rawoptions as $raw) {
        if (substr($raw, 0, 2) === '--') {
            $value = substr($raw, 2);
            $parts = explode('=', $value);
            if (count($parts) == 1) {
                $key   = reset($parts);
                $value = true;
            } else {
                $key = array_shift($parts);
                $value = implode('=', $parts);
            }
            if (array_key_exists($key, $longoptions)) {
                $options[$key] = $value;
            } else {
                $unrecognized[] = $raw;
            }

        } else if (substr($raw, 0, 1) === '-') {
            $value = substr($raw, 1);
            $parts = explode('=', $value);
            if (count($parts) == 1) {
                $key   = reset($parts);
                $value = true;
            } else {
                $key = array_shift($parts);
                $value = implode('=', $parts);
            }
            if (array_key_exists($key, $shortmapping)) {
                $options[$shortmapping[$key]] = $value;
            } else {
                $unrecognized[] = $raw;
            }
        } else {
            $unrecognized[] = $raw;
            continue;
        }
    }
    //apply defaults
    foreach ($longoptions as $key=>$default) {
        if (!array_key_exists($key, $options)) {
            $options[$key] = $default;
        }
    }
    // finished
    return array($options, $unrecognized);
}

/**
 * Print or return section separator string
 * @param bool $return false means print, true return as string
 * @return mixed void or string
 */
function cli_separator($return=false) {
    $separator = str_repeat('-', 79).PHP_EOL;
    if ($return) {
        return $separator;
    } else {
        cli_write($separator);
    }
}

/**
 * Print or return section heading string
 * @param string $string text
 * @param bool $return false means print, true return as string
 * @return mixed void or string
 */
function cli_heading($string, $return=false) {
    $string = "== $string ==".PHP_EOL;
    if ($return) {
        return $string;
    } else {
        cli_write($string);
    }
}

/**
 * Write error notification
 * @param $text
 * @return void
 */
function cli_problem($text) {
    cli_writeln($text, STDERR);
}

/**
 * Write to standard error output and exit with the given code
 *
 * @param string $text
 * @param int $errorcode
 * @return void (does not return)
 */
function cli_error($text, $errorcode=1) {
    cli_writeln($text.PHP_EOL, STDERR);
    die($errorcode);
}

/*
 * Add quotes to HTML characters.
 *
 * Returns $var with HTML characters (like "<", ">", etc.) properly quoted.
 * Related function {@link p()} simply prints the output of this function.
 *
 * @param string $var the string potentially containing HTML characters
 * @return string
 */
function s($var) {

    if ($var === false) {
        return '0';
    }

    // When we move to PHP 5.4 as a minimum version, change ENT_QUOTES on the
    // next line to ENT_QUOTES | ENT_HTML5 | ENT_SUBSTITUTE, and remove the
    // 'UTF-8' argument. Both bring a speed-increase.
    return preg_replace('/&amp;#(\d+|x[0-9a-f]+);/i', '&#$1;', htmlspecialchars($var, ENT_QUOTES, 'UTF-8'));
}

/**
 * Load core_component from a Moodle (without needing a fully
 * installed moodle isntance).
 *
 * @param string $moodledirroot The path to moodle's dirroot
 * @return bool false if core_component wasn't able to be loaded.
 */
function load_core_component_from_moodle($moodledirroot) {
    if (file_exists($moodledirroot . '/public/lib/classes/component.php')) {
        // Support the Moodle 5.1 'public' directory structure.
        $newcfg = (object) [
            'dirroot' => "{$moodledirroot}/public",
            'root' => $moodledirroot,
            'libdir' => "{$moodledirroot}/public/lib",
        ];
    } else if (file_exists($moodledirroot . '/lib/classes/component.php')) {
        $newcfg = (object) [
            'dirroot' => $moodledirroot,
            'libdir' => $moodledirroot . '/lib',
        ];
    } else {
        return false;
    }

    define('IGNORE_COMPONENT_CACHE', 1);
    define('MOODLE_INTERNAL', 1);
    unset($CFG);
    global $CFG;
    $CFG = $newcfg;
    $CFG->admin = 'admin';
    $CFG->filepermissions = '0666';

    require_once($CFG->libdir . '/classes/component.php');

    return true;
}
