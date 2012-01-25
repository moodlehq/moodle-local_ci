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
 * Simple wrapper over the phpcpd PECL tool (copy/paste detector)
 * https://github.com/sebastianbergmann/phpcpd
 *
 * This script looks for duplicated sections of code againt the codebase
 * reporting them in PMD format, so can be processed later by some tools
 * like DRY (don't repeat yourself) ones. Useful to build some CI jobs
 * on top of it.
 *
 * @package    core
 * @subpackage ci
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

// Increase memory, codebase is huge
ini_set('memory_limit', '2048M');

require 'PHPCPD/Autoload.php';
PHPCPD_TextUI_Command::main();
