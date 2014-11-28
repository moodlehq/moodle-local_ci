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
 * Given a list of component directories, returns a list of third party
 * library directories (defined by thirdpartylibs.xml)
 *
 * @category   ci
 * @package    local_ci
 * @subpackage thirdparty_check
 * @copyright  2014 Dan Poltawski
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */


while ($dir = trim(fgets(STDIN))) {
    $xmlfile = $dir.'/thirdpartylibs.xml';
    print_thirdparty_info($xmlfile, $dir);
    $libxmlfile = $dir.'/lib/thirdpartylibs.xml';
    print_thirdparty_info($libxmlfile, $dir.'/lib');
}

/**
 * print thirdparty directories info from xmlfile path, echos the
 * info out in format:
 * pathofdirectory,pathtothirdpartyxmlfile,pathtoreadmemoodle
 *
 * @param string $xmlfile the file to get directories from
 * @param string $basepath the path to base directories of
 */
function print_thirdparty_info($xmlfile, $basepath) {
        if (!file_exists($xmlfile)) {
            return;
        }
        $simplexml = simplexml_load_file($xmlfile);
        $subdirectories = $simplexml->xpath('//libraries/library/location');

        $dirs = array();
        foreach ($subdirectories as $subdirectory) {
            $path = $basepath.'/'.$subdirectory;

            // Workout a path for the readme file..
            if (strpos(basename($subdirectory), '.') !== false) {
                // Its a filename,the filename from the directory.
                $readmesubdir = dirname($subdirectory);
            } else {
                $readmesubdir = $subdirectory;
            }

            if ($readmesubdir == '.') {
                $readmepath = $basepath;
            } else {
                $readmepath = $basepath.'/'.$readmesubdir;
            }

            // Readme search, NOTE intentional duplicate on the end to default to in the case
            // NOTE the README_MOODLE.txt can have problems on HFS+!!
            // TODO: We should make these readme files get named consitently..
            $readmenames = array('readme_moodle.txt', 'moodle_readme.txt', 'README_MOODLE.txt', 'readme_moodle.txt');
            $readme = ''; // Will end up as 'readme_moodle.txt' if reach the end of this looop.
            foreach ($readmenames as $readmename) {
                $readme = $readmepath.'/'.$readmename;
                if (file_exists($readme)) {
                    break;
                }
            }

            echo $path.','.$xmlfile.','.$readme."\n";
        }
}
