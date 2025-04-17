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

[$options, $unrecognized] = cli_get_params(
    [
        'help' => false,
        'commitid' => '',
        'git' => '/usr/bin/git',
    ],
    [
        'h' => 'help',
        'c' => 'commitid',
        'g' => 'git',
    ]
);

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
-g, --git           The path to the git binary
";
    echo $help;
    exit(0);
}

if (empty($options['commitid'])) {
    cli_error('--commitid missing. Use --help to get more info.');
}

$COMMIT = $options['commitid'];

$commitmessagecmd = [
    escapeshellcmd($options['git']),
    "show",
    "--no-patch",
    "--format=%B",
    escapeshellarg($COMMIT),
];
exec(join(" ", $commitmessagecmd), $output, $returncode);
if ($returncode !== 0) {
    cli_error("Error running git show command: " . implode("\n", $output));
}
$message = join("\n", $output);

$filelistcmd = [
    escapeshellcmd($options['git']),
    "diff-tree",
    "--no-commit-id",
    "--name-only",
    "-r",
    escapeshellarg($COMMIT),
];

exec(join(" ", $filelistcmd), $output, $returncode);
if ($returncode !== 0) {
    cli_error("Error running git diff-tree command: " . implode("\n", $output));
}
$filesmodified = join(",", $output);

$returncode = amos_script_parser::validate_commit_message($message, $filesmodified);
exit($returncode);
