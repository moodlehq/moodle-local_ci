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
 * Check travis status of passed git branch. Returns output starting
 * with (WARNING|ERROR|OK) with a summary status.
 *
 * @copyright  2016 Dan Poltawski <dan@moodle.com>
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

require_once(__DIR__.'/../phplib/clilib.php');

list($options, $unrecognized) = cli_get_params(
    array('help' => false, 'repository' => '', 'branch' => ''),
    array('h' => 'help', 'r' => 'repository', 'b' => 'branch'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$unrecognized}\n Please use --help option.");
}

if ($options['help']) {
    $help =
"Check a git branch status against travis. Exits non-zero if the build has failed and
returns the url for the build. Else returns the status.

Options:
-h, --help            Print out this help
-r, --repository      git repository url
-b, --branch          git branch
";
    echo $help;
    exit(0);
}

if (empty($options['repository']) || empty($options['branch'])) {
    cli_error('--repository and --branch missing. Use --help to get more info.');
}

if (!preg_match('#^(https|git)://github.com/([^/]+)/([^\./]+)#', $options['repository'], $matches)) {
    echo "SKIP: Skipping checks. {$options['repository']} Not a github repo.\n";
    exit(0);
}

$username = $matches[2];
$reponame = $matches[3];
$branchname = $options['branch'];

$info = travis_api_request('/repos/'.$username.'/'.$reponame);

if (!isset($info->repo->active) || !$info->repo->active) {
    echo "WARNING: Travis integration not setup. See https://docs.moodle.org/dev/Travis_Integration\n";
    exit(0);
}

$json = travis_api_request('/repos/'.$username.'/'.$reponame.'/branches/'.$branchname);

if (isset($json->branch->state)) {
    $buildurl = 'https://travis-ci.org/'.$username.'/'.$reponame.'/builds/'.$json->branch->id;
    switch ($json->branch->state) {
        case 'failed':
            echo 'ERROR: Build failed, see '.$buildurl."\n";
            break;
        case 'canceled':
            echo 'WARNING: Build canceled, see '.$buildurl."\n";
            break;
        default:
            echo "OK: Build status was {$json->branch->state}, see $buildurl\n";
            break;
    }
} else {
    // This could be because it doesn't exist.
    echo "OK: Unknown state of $username/$reponame/$branchname\n";
}
exit(0);

/**
 * Does a GET request to travis api.
 *
 * @param string $path the api path to call.
 * @return json_decoded response from the api
 */
function travis_api_request($path) {
    $curl = curl_init();
    curl_setopt($curl, CURLOPT_HTTPHEADER, ['Accept: application/vnd.travis-ci.2+json']);
    curl_setopt($curl, CURLOPT_URL, 'https://api.travis-ci.org'.$path);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
    $result = curl_exec($curl);
    curl_close($curl);
    return json_decode($result);
}
