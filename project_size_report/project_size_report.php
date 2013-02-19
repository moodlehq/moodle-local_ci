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
 * Simple wrapper over the phploc PECL tool (size reporter)
 * https://github.com/sebastianbergmann/phploc
 *
 * To track various codebase size aspects.
 *
 * @package    core
 * @subpackage ci
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

// Increase memory, codebase is huge
ini_set('memory_limit', '1024M');

if (strpos('/opt/local/bin/php', '@php_bin') === 0) {
        require __DIR__ . DIRECTORY_SEPARATOR . 'src' . DIRECTORY_SEPARATOR . 'autoload.php';
} else {
        require 'SebastianBergmann/PHPLOC/autoload.php';
}

$textui = new SebastianBergmann\PHPLOC\TextUI\Command;
$textui->main();
