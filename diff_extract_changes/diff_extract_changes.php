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
 * Extract all modified lines from an unified diff file
 *
 * The script, given the path to one unified diff file will return
 * all the changes into one format suitable to be used later by
 * other tools.
 *
 * Basically, it returns both files in the diff plus the changed lines
 * on each one. Such information will be used later for a lot of static
 * code analyzers to determine if the changes are introducing new errors.
 *
 * @category   ci
 * @package    local_ci
 * @subpackage diff_extract_changes
 * @copyright  2012 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('NO_OUTPUT_BUFFERING', true);

require(dirname(dirname(dirname(dirname(__FILE__)))).'/config.php');
require_once($CFG->libdir.'/clilib.php');      // cli only functions

// now get cli options
list($options, $unrecognized) = cli_get_params(
    array('help' => false, 'diff' => 'example.diff', 'output' => 'txt'),
    array('h' => 'help', 'd' => 'diff', 'o' => 'output'));

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if (empty($options['diff'])) {
    cli_error('Missing diff file. Use the --diff option to specify one diff file.');
}

if (empty($options['output'])) {
    cli_error('Missing output format. Use the --output option to specify one format (txt|xml).');
}

if (!file_exists($options['diff']) || !is_readable($options['diff'])) {
    cli_error('Diff file not available or unreadable (' . $options['diff'] . ').');
}

if ($options['output'] !== 'txt' && $options['output'] !== 'xml') { // Only supported for now
    cli_error('Unsupported output format (' . $options['output'] . ').');
}

if ($options['help']) {
    $help =
"Extract all the changes performed by one unified diff file

Options:
-h, --help            Print out this help
--
-d, --diff            Unified diff file to process
-o, --output          Output format (txt or xml)

Example:
\$sudo -u www-data /usr/bin/php admin/ci/diff_extract_changes/diff_extract_changes.php --file=example.diff --output=txt
";
    echo $help;
    exit(0);
}

$dec = new diff_changes_extractor($options['diff'], $options['output']);
$dec->process();

/**
 * Unified diff changes extractor
 *
 * Worker class that given one unified diff file and one output format
 * will extract all the existing changes, annotating each file and lines
 * modified. Suitable to select interesting information from any static
 * code analyzer by intersecting results.
 *
 * @copyright  2012 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */
class diff_changes_extractor {

    /** version of the extractor */
    const VERSION = '20120120';

    /** @var string The unified diff file to process */
    protected $file;

    /** @var string The output format to utilize (txt, xml) */
    protected $output;

    /**
     * Create one instance of the diff extractor
     *
     * @param string $file   path to the unified diff file
     * @param string $output format to output the information (txt|xml)
     *
     * @return diff_changes_extractor
     */
    public function __construct($file, $output) {
        // TODO: apply the checks and defaults already available in the CLI
        $this->file = $file;
        $this->output = $output;
    }

    /**
     * Process one unified diff file, and output all the files/lines changed
     *
     * This function processes any unified diff file, outputing the changes
     * in txt or xml format, suitable for integration with other tools
     */
    public function process() {

        // Init some vars
        $cfile = ''; // Current file
        $clineinfile = 0; // Current line in current file
        $clineint = array(); // Current line interval being modfied

        // Skip always these lines
        $skiplines = array('diff', 'inde', '--- ');

        // Let's read the diff file, line by line.
        $fh = fopen($this->file, 'r');
        if ($fh) {
            // Start, output begin
            $this->output_begin();

            while (($line = fgets($fh, 4096)) !== false) {
                // Get very 4 first chars, that's enough to analyze the diff
                $lineheader = substr($line, 0, 4);

                // We can safely ignore some lines
                if (in_array($lineheader, $skiplines)) {
                    continue;
                }

                // Detect if we are changing of file
                if ($lineheader === '+++ ') {
                    // Output interval end
                    if (!empty($clineint)) {
                        $this->output_interval_end($clineint);
                    }
                    // Output file end
                    if ($cfile) {
                        $this->output_file_end($cfile);
                    }
                    // Reset variables for new file
                    if (!preg_match('/^\+\+\+ (b\/)?(.*)/', $line, $match)) {
                        print_error('Error: Something went wrong matching file. Line: ' . $line);
                    }
                    $cfile = $match[2];
                    $clineinfile = 0;
                    $clineint = array();
                    // Output file begin
                    $this->output_file_begin($cfile);
                    continue;
                }

                // Detect if we are changing of chunk
                if ($lineheader === '@@ -') {
                    // Output interval end
                    if (!empty($clineint)) {
                        $this->output_interval_end($clineint);
                    }
                    // Change variables for new chunk
                    if (!preg_match('/^@@ .*\+(\d*),.*/', $line, $match)) {
                        print_error('Error: Something went wrong matching chunk. Line: ' . $line);
                    }
                    $clineinfile = $match[1] - 1; // Position to line before chunk begins
                    $clineint = array();
                    continue;
                }

                // Arrived here, we only need the 1st char
                $linefirst = substr($lineheader, 0, 1);

                // minus (-) found, deleted line, do nothing
                if ($linefirst === '-') {
                    continue;
                }

                // space ( ) found, increment $clineinfile and finish interval
                if ($linefirst === ' ') {
                    $clineinfile++;
                    // Output interval end
                    if (!empty($clineint)) {
                        $this->output_interval_end($clineint);
                    }
                    $clineint = array();
                    continue;
                }

                // plus (+) found, increment $clineinfile and start/continue interval
                if ($linefirst === '+') {
                    $clineinfile++;
                    if (empty($clineint)) {
                        $clineint = array($clineinfile, $clineinfile);
                        // Output interval begin
                        $this->output_interval_begin($clineint);
                    } else {
                        $clineint[1] = $clineinfile;
                    }
                    continue;
                }
            }
            if (!feof($fh)) {
                print_error('Error: Something went wrong reading ' . $this->file);
            }
            fclose($fh);
            // Output interval end
            if (!empty($clineint)) {
                $this->output_interval_end($clineint);
            }
            // output file end
            if ($cfile) {
                $this->output_file_end($cfile);
            }
            // Finished, output end
            $this->output_end();
        }
    }

// Helper functions used to output information in the desired output

    /**
     * Output begin of the changes
     */
    private function output_begin() {
        if ($this->output == 'xml') {
            echo '<?xml version="1.0" encoding="UTF-8" ?>' . PHP_EOL;
            echo '<diffchanges version="' . self::VERSION . '">' . PHP_EOL;
        }
    }

    /**
     * Output end of the changes
     */
    private function output_end() {
        if ($this->output == 'xml') {
            echo '</diffchanges>';
        }
    }

    /**
     * Output begin of file changes
     *
     * @param string $file path of the file we are going to show changes
     */
    private function output_file_begin($file) {
        if ($this->output == 'xml') {
            echo '  <file name="' . $file . '">' . PHP_EOL;
        } else {
            echo $file . ':';
        }
    }

    /**
     * Output bend of file changes
     *
     * @param string $file path of the file we are going to show changes
     */
    private function output_file_end($file) {
        if ($this->output == 'xml') {
            echo '  </file>' . PHP_EOL;
        } else {
            echo PHP_EOL;
        }
    }

    /**
     * Output begin of interval of line changes
     *
     * @param array $interval of lines changed
     */
    private function output_interval_begin($interval) {
        if ($this->output == 'xml') {
            echo '    <lines from="' . $interval[0] . '" ';
        } else {
            echo $interval[0] . '-';
        }
    }

    /**
     * Output end of interval of line changes
     *
     * @param array $interval of lines changed
     */
    private function output_interval_end($interval) {
        if ($this->output == 'xml') {
            echo 'to="' . $interval[1] . '" />' . PHP_EOL;
        } else {
            echo $interval[1] . ';';
        }
    }
}
