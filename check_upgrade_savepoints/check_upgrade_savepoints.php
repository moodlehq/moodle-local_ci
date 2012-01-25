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

$dir = dirname(__FILE__);

$files = files_to_check($dir);

foreach ($files as $file) {
    echo "  - $file: " . LINEFEED;

    $contents = file_get_contents($file);

    $function_regexp = '\s*function\s+xmldb_[a-zA-Z0-9_]+?_upgrade\s*\(.*?version.*?\)\s*(?=\{)';

/// Find we have some xmldb_xxxx_function in code
    if (! $count = preg_match_all('@' . $function_regexp . '@is', $contents, $matches)) {
        echo "    + NOTE: upgrade function not found" . LINEFEED;
        continue;
    }
/// Verify there is only one upgrade function
    if ($count !== 1) {
        echo "    + ERROR: multiple upgrade functions detected" . LINEFEED;
        continue;
    }
/// Arrived here, extract function contents
    if (! preg_match_all('@' . $function_regexp . '.*?(\{(?>(?>[^{}]+)|(?1))*\})@is', $contents, $matches)) {
        echo "    + NOTE: cannot find upgrade function contents" . LINEFEED;
        continue;
    }

/// Calculate function contents (must be a group of "if" blocks)
    $contents = trim(trim($matches[1][0], '}{'));

    $if_regexp = 'if\s+?\(\s*?\$oldversion\s*?<\s*?([0-9.]{8,13}).*?\)\s*?';
    $sp_regexp = 'upgrade_(main|mod|block|plugin)_savepoint\s*?\(\s*?true\s*?,\s*?([0-9.]{8,13})\s*?.*?\);';

/// Count ifs and savepoints. Must match
    $count_if = preg_match_all('@' . $if_regexp . '@is', $contents, $matches1);
    $count_sp = preg_match_all('@' . $sp_regexp . '@is', $contents, $matches2);
    if ($count_if > 0 || $count_sp > 0) {
        if ($count_if !== $count_sp) {
            if ($count_if < $count_sp) {
                echo "    + WARN: Detected less 'if' blocks ($count_if) than 'savepoint' calls ($count_sp). Repeated savepoints?" . LINEFEED;
            } else {
                echo "    + ERROR: Detected more 'if' blocks ($count_if) than 'savepoint' calls ($count_sp)" . LINEFEED;
            }
        } else {
            echo "    + found $count_if matching 'if' blocks and 'savepoint' calls" . LINEFEED;
        }
    }

/// Let's split them
    if (!preg_match_all('@(' . $if_regexp . '(\{(?>(?>[^{}]+)|(?3))*\}))@is', $contents, $matches)) {
        echo "    + NOTE: cannot find 'if' blocks within the upgrade function" . LINEFEED;
        continue;
    }

    $versions = $matches[2];
    $blocks = $matches[3];

/// Foreach version, check order
    $version_p = 0;
    $has_version_error = false;
    foreach($versions as $version) {
        if (!$version_p) {
            $version_p = $version;
            continue;
        }
        if (((float)$version * 100) < ((float)$version_p * 100)) {
            echo "    + ERROR: Wrong order in versions: $version_p and $version" . LINEFEED;
            $has_version_error = true;
        }
        $version_p = $version;
    }
    if (!$has_version_error) {
        echo "    + versions in upgrade blocks properly ordered" . LINEFEED;
    }

/// Foreach version, look for corresponding savepoint
    $has_version_mismatch = false;
    foreach ($versions as $key => $version) {
        $count_spv = preg_match_all('@' .$sp_regexp . '@is', $blocks[$key], $matches);
        if ($count_spv == 0) {
            echo "    + ERROR: version $version is missing corresponding savepoint call" . LINEFEED;
            $has_version_mismatch = true;
        } else if ($count_spv > 1) {
            echo "    + WARN: version $version has more than one savepoint call" . LINEFEED;
            $has_version_mismatch = true;
        } else {
            if ($version !== $matches[2][0]) {
                echo "    + ERROR: version $version has wrong savepoint call with version {$matches[2][0]}" . LINEFEED;
                $has_version_mismatch = true;
            }
        }
    }
    if (!$has_version_mismatch) {
        echo "    + versions in savepoint calls properly matching upgrade blocks" . LINEFEED;
    }
}

    /**
     * Given one full path, return one array with all the files to check
     */
    function files_to_check($path) {

        $results = array();
        $pending = array();

        $dir = opendir($path);
        while (false !== ($file=readdir($dir))) {

            $fullpath = $path . '/' . $file;

            if (substr($file, 0, 1)=='.' || $file=='CVS') { /// Exclude some dirs
                continue;
            }

            if (is_dir($fullpath)) { /// Process dirs later
                $pending[] = $fullpath;
                continue;
            }

            if (is_file($fullpath) && strpos($file, basename(__FILE__))!==false) { /// Exclude me
                continue;
            }

            if (is_file($fullpath) && strpos($fullpath, 'db/upgrade.php')===false) { /// Exclude non upgrade.php files
                continue;
            }

            if (!in_array($fullpath, $results)) { /// Add file if doesn't exists
                $results[$fullpath] = $fullpath;
            }
        }
        closedir($dir);

        foreach ($pending as $pend) {
            $results = array_merge($results, files_to_check($pend));
        }

        return $results;
    }
?>
