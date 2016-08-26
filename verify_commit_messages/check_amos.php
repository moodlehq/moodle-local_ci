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

require_once(__DIR__.'/../phplib/clilib.php');
require_once(__DIR__.'/amoslib.php');

list($options, $unrecognized) = cli_get_params(
    array('help' => false, 'commitid' => '', 'filesmodified' => ''),
    array('h' => 'help', 'c' => 'commitid', 'f' => 'filesmodified'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$unrecognized}\n Please use --help option.");
}

if ($options['help']) {
    $help =
"Checks a git commit against amos comamnds

Options:
-h, --help            Print out this help
-c, --commitid      git commit hash
-f, --filesmodified files modified by commit (comma seperated)
";
    echo $help;
    exit(0);
}

if (empty($options['commitid'])) {
    cli_error('--commitid missing. Use --help to get more info.');
}

if (empty($options['filesmodified'])) {
    cli_error('--filesmodified missing. Use --help to get more info.');
}

$COMMIT = $options['commitid'];

$message = file_get_contents("php://stdin");
$returncode = amos_script_parser::validate_commit_message($message, $options['filesmodified']);
exit($returncode);
