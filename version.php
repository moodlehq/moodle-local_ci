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
 * CI scripts version information
 *
 * @package    local_ci
 * @copyright  2012 onwards Eloy Lafuente (stronk7) {@link http://stronk7.com}
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die;

$plugin->version   = 2012113000;
$plugin->requires  = 2013070400;        // Moodle 2.6dev (Build 20130704) and upwards.
$plugin->dependencies = array(          // Also requires these plugins to be installed.
    'local_moodlecheck' => '2012011000',
);
$plugin->component = 'local_ci';
$plugin->release   = '0.9.1';
$plugin->maturity  = MATURITY_BETA;
