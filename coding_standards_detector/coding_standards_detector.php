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
 * Simple wrapper over the phpmd PECL tool (mess detector)
 * http://phpmd.org
 *
 * This script looks for various mess analysis (codesize, design, naming,
 * unused) - by default we execute all reporting them in PMD format
 * so can be processed later by some PMD tools. Useful to build some CI jobs
 * on top of it.
 *
 * @package    core
 * @subpackage ci
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

// Increase memory, codebase is huge
ini_set('memory_limit', '4352M');

error_reporting(E_ALL | E_STRICT);
include_once 'PHP/CodeSniffer/CLI.php';
$phpcs = new PHP_CodeSniffer_CLI();
$phpcs->checkRequirements();
$numerrors = $phpcs->process();
if ($numerrors === 0) {
    exit(0);
} else {
    exit(1);
}
