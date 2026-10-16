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
 * @package   contrib-tools
 * @copyright 2003 onwards Eloy Lafuente (stronk7) {@link http://stronk7.com}
 * @license   http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 *
 * This script looks for all the upgrade.php files under the dir where it's
 * executed performing some basic validation of the upgrade blocks and their
 * uses of the upgrade_xxxx_savepoint() functions. Note it isn't 100% acurate
 * but detects some usual errors.
 *
 * Simply copy it to moodle root dir (or to your module/plugin dir) and launch
 * it from command line or browser.
 */

if (isset($_SERVER['REMOTE_ADDR'])) {
    define('LINEFEED', "<br />");
} else {
    define('LINEFEED', "\n");
}

$plugin = new stdClass();
$module = new stdClass();

$dir = dirname(__FILE__);
$files = files_to_check($dir);

foreach ($files as $file) {
    echo "  - $file: " . LINEFEED;

    $contents = file_get_contents($file);

    $functionregexp = '\s*function\s+xmldb_[a-zA-Z0-9_]+?_upgrade\s*\(.*?version.*?\)(?::\sbool)?\s*(?=\{)';
    $returnregexp = '\s*return true;';
    $anyfunctionregexp = '\s*function\s*[a-z0-9_]+?\s*\(.*?\)\s*{'; // MDL-34103

    // Find we have some xmldb_xxxx_function in code
    if (! $countxmldb = preg_match_all('@' . $functionregexp . '@is', $contents, $matches)) {
        echo "    + ERROR: upgrade function not found" . LINEFEED;
        continue;
    }
    // Verify there is only one upgrade function
    if ($countxmldb !== 1) {
        echo "    + ERROR: multiple upgrade functions detected" . LINEFEED;
        continue;
    }

    // Find we have some return true; in code
    if (! $countreturn = preg_match_all('@' . $returnregexp . '@is', $contents, $matches)) {
        echo "    + ERROR: 'return true;' not found" . LINEFEED;
        continue;
    }
    // Verify there is only one return true;
    if ($countreturn !== 1) {
        echo "    + ERROR: multiple 'return true;' detected" . LINEFEED;
        continue;
    }

    // Verify there is not more than one function
    if (preg_match_all('@' . $anyfunctionregexp . '@is', $contents, $matches) > 1) {
        echo "    + ERROR: multiple functions detected (use upgradelib, plz)" . LINEFEED;
        continue;
    }

    // Extract all string literals in upgrade code, we are not interested on them and can lead to
    // incorrect calculation of function body later, see MDLSITE-4366. Replace them with simple placeholders.
    //
    // Note that, while we can simply discard the literals because they are not used later by any
    // check... instead... we are being selective here, replacing the "conflictive" ones by simpler,
    // safe alternatives and keeping the simple ones in place. That would help if we want it the future
    // perfomr checks to savepoint function parameters or whatever.
    // In any case, all the replacements performed are stored in $discardedliterals just in case
    // something needs to be recovered back.
    $regexp = '(["\'])(?:\\\\\1|.)*?\1'; // Match all quoted literals in a text, ignoring escaped ones.
    $discardedliterals = [];
    // Look for all quoted strings.
    preg_match_all('@' . $regexp . '@', $contents, $matches);
    // Iterate them, keeping safe ones and replacing by placeholder conflictive ones.
    // All replacements are stored into $discardedliterals in case it's needed for any reason.
    foreach (array_unique($matches[0]) as $key => $string) {
        $unsaferegexp = '[\[\(\{\<\>\}\)\]]'; // Consider everything but [({<>})] safe.
        if (preg_match('@' . $unsaferegexp . '@', $string)) {
            // The string is not safe, replace it by placeholder and annotate the replacement.
            $replacement = "'<%&%" . (string)(count($discardedliterals) + 1) . "%&%>'";
            $discardedliterals[$replacement] = $string;
        } else {
             // The string is safe, keep it as is, no need to replace it by placeholder.
        }
    }
    // If there are literals to discard, perform them.
    if (!empty($discardedliterals)) {
        $contents = str_replace($discardedliterals, array_keys($discardedliterals), $contents);
    }

    // Arrived here, extract function contents
    if (! preg_match_all('@' . $functionregexp . '.*?(\{(?>(?>[^{}]+)|(?1))*\})@is', $contents, $matches)) {
        echo "    + NOTE: cannot find upgrade function contents" . LINEFEED;
        continue;
    }

    // Calculate function contents (must be a group of "if" blocks)
    $contents = trim(trim($matches[1][0], '}{'));

    $ifregexp = 'if\s+?\(\s*?\$oldversion\s*?<\s*?([0-9.]{8,13}).*?\)\s*?';
    $spregexp = 'upgrade_(main|mod|block|plugin)_savepoint\s*?\(\s*?true\s*?,\s*?([0-9.]{8,13})\s*?.*?\);';

    // Count ifs and savepoints. Must match
    $countif = preg_match_all('@' . $ifregexp . '@is', $contents, $matches1);
    $countsp = preg_match_all('@' . $spregexp . '@is', $contents, $matches2);
    if ($countif > 0 || $countsp > 0) {
        if ($countif !== $countsp) {
            if ($countif < $countsp) {
                echo "    + WARN: Detected fewer 'if' blocks ($countif) than 'savepoint' calls ($countsp). Repeated savepoints?" . LINEFEED;
            } else {
                echo "    + ERROR: Detected more 'if' blocks ($countif) than 'savepoint' calls ($countsp)" . LINEFEED;
            }
        } else {
            echo "    + found $countif matching 'if' blocks and 'savepoint' calls" . LINEFEED;
        }
    }

    // Let's ensure there are no duplicate calls to a save point with the same version.
    if ($countsp > 0) {
        foreach (array_count_values($matches2[2]) as $version => $count) {
            if ($count > 1) {
                echo "    + ERROR: Detected multiple 'savepoint' calls for version $version" . LINEFEED;
            }
        }
    }

    // Let's split them
    if (!preg_match_all('@(' . $ifregexp . '(\{(?>(?>[^{}]+)|(?3))*\}))@is', $contents, $matches)) {
        echo "    + NOTE: cannot find 'if' blocks within the upgrade function" . LINEFEED;
        continue;
    }

    $versions = $matches[2];
    $blocks = $matches[3];

    // Foreach version, check order
    $versionp = 0;
    $hasversionerror = false;
    foreach ($versions as $version) {
        if (!$versionp) {
            $versionp = $version;
            continue;
        }
        if (((float)$version * 100) < ((float)$versionp * 100)) {
            echo "    + ERROR: Wrong order in versions: $versionp and $version" . LINEFEED;
            $hasversionerror = true;
        }
        $versionp = $version;
    }
    if (!$hasversionerror) {
        echo "    + versions in upgrade blocks properly ordered" . LINEFEED;
    }

    // Foreach version, look for corresponding savepoint
    $hasversionmismatch = false;
    foreach ($versions as $key => $version) {
        $countspv = preg_match_all('@' . $spregexp . '@is', $blocks[$key], $matches);
        if ($countspv == 0) {
            echo "    + ERROR: version $version is missing corresponding savepoint call" . LINEFEED;
            $hasversionmismatch = true;
        } else if ($countspv > 1) {
            echo "    + ERROR: version $version has more than one savepoint call" . LINEFEED;
            $hasversionmismatch = true;
        } else {
            if ($version !== $matches[2][0]) {
                echo "    + ERROR: version $version has wrong savepoint call with version {$matches[2][0]}" . LINEFEED;
                $hasversionmismatch = true;
            }
        }
    }
    if (!$hasversionmismatch) {
        echo "    + versions in savepoint calls properly matching upgrade blocks" . LINEFEED;
    }

    // Ensure a plugin does not upgrade past its defined version.
    $versionfile = dirname(dirname($file)) . '/version.php';
    if (file_exists($versionfile)) {
        if (preg_match('/^\s*\$(module|plugin)->version\s*=\s*([\d.]+)/m', file_get_contents($versionfile), $versionmatches) === 1) {
            foreach ($versions as $version) {
                if (((float) $versionmatches[2] * 100) < ((float) $version * 100)) {
                    echo "    + ERROR: version $version is higher than that defined in $versionfile file" . LINEFEED;
                }
            }
        }
    }
}

    /**
     * Given one full path, return one array with all the files to check
     */
function files_to_check($path) {

    $results = [];
    $pending = [];

    $dir = opendir($path);
    while (false !== ($file = readdir($dir))) {
        $fullpath = $path . '/' . $file;

        if (substr($file, 0, 1) == '.' || $file == 'CVS' || $file == '.git') { // Exclude some dirs
            continue;
        }

        if (is_dir($fullpath)) { // Process dirs later
            $pending[] = $fullpath;
            continue;
        }

        if (is_file($fullpath) && strpos($file, basename(__FILE__)) !== false) { // Exclude me
            continue;
        }

        if (is_file($fullpath) && strpos($fullpath, 'db/upgrade.php') === false) { // Exclude non upgrade.php files
            continue;
        }

        if (!in_array($fullpath, $results)) { // Add file if doesn't exists
            $results[$fullpath] = $fullpath;
        }
    }
    closedir($dir);

    foreach ($pending as $pend) {
        $results = array_merge($results, files_to_check($pend));
    }

    return $results;
}
