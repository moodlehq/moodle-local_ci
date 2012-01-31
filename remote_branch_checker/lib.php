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
 * Library of classes/functions to execute the remote_branch_reporter
 *
 * @category   ci
 * @package    local_ci
 * @subpackage remote_branch_checker
 * @copyright  2011 Eloy Lafuente (http://stronk7.com)
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

class remote_branch_reporter {

    /** working directory where all the files are generated */
    protected $directory;

    public function __construct($directory) {
        if (!file_exists($directory) or !is_dir($directory) or !is_readable($directory)) {
            throw new exception('Incorrect directory: ' . $directory);
        }
        $this->directory = $directory;

    }

    /**
     * Run the report, by transforming all the individual xml files
     * from various reports into one big smurf xml file that, finally,
     * will be rendered in the specified output format and filtered
     * using the patchset.xml file specified
     */
    public function run($format, $patchset) {

        // Main smurf Dom where everything will be aggregated
        $doc = new DomDocument();
        $smurf = $doc->createElement('smurf');
        $smurf->setAttribute('version', '0.9.0');

        $doc->appendChild($smurf);

        // Process the savepoints output, weighting errors with 50 and warnings with 10
        $params = array(
            'title' => 'Update savepoints problems',
            'description' => 'This sections shows problems detected with the handling of upgrade savepoints',
            'url' => 'http://docs.moodle.org/dev/Upgrade_API',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 50,
            'warningweight' => 10);
        if ($node = $this->process_cs($params, 'savepoints.xml')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Process the cs output, weighting errors with 5 and warnings with 1
        $params = array(
            'title' => 'Coding style problems',
            'description' => 'This sections shows the coding style problems detected in the code by phpcs',
            'url' => 'http://docs.moodle.org/dev/Coding_style',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 5,
            'warningweight' => 1);
        if ($node = $this->process_cs($params, 'cs.xml')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Process the docs output, weighting errors with 3 and warnings with 1
        $params = array(
            'title' => 'PHPDocs style problems',
            'description' => 'This sections shows the phpdocs problems detected in the code by local_moodlecheck',
            'url' => 'http://docs.moodle.org/dev/Coding_style',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 3,
            'warningweight' => 1);
        if ($node = $this->process_cs($params, 'docs.xml')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Conditionally, perform the filtering
        if ($patchset) {
            $this->patchset_filter($doc, $patchset);
        }

        // And finally return the results
        switch ($format) {
            case 'xml':
                return $doc->saveXML();
                break;
            default:
                throw new exception('Sorry, format not implemented: ' . $format);
        }
    }

    /**
     * Given one already built DOMDcocument and one patchset.xml file
     * filter the document so only target lines are shown
     */
     protected function patchset_filter($doc, $file) {
        $file = $this->directory . '/' . $file;
        if (!is_readable($file)) {
            throw new exception('Error: cannot access to the patchset xml file: ' . $patchset);
        }
        // Load patchsetinfo
        $patchsetinfo = $this->load_patchset_file($file);

        // Iterate over all the 'problem' nodes in the document,
        // filtering them out if no matching is found in the patchset
        $xpath = new DOMXPath($doc);
        $problems = $xpath->query('//smurf/check/mess/problem');
        foreach ($problems as $problem) {
            // TODO: Not good to pass the whole array all the time, but ok for now
            if (!$this->problem_matches($problem, $patchsetinfo)) {
                $problem->parentNode->removeChild($problem);
            }
        }
     }

     /**
      * Given one problem and the patchsetinfo, return if the former matches
      *
      * @todo: Avoid passing the $patchsetinfo all the time
      */
      protected function problem_matches($problem, $patchsetinfo) {

          // No file, linefrom, lineto, impossible to match
          if (!$problem->hasAttribute('file') or
                  !$problem->hasAttribute('linefrom') or
                  !$problem->hasAttribute('lineto')) {
              return false;
          }
          // Extract the attributes we need to perform the match
          $file = $problem->getAttribute('file');
          $linefrom = $problem->getAttribute('linefrom');
          $lineto = $problem->getAttribute('lineto');

          // If the file is not present in the patchset, no match
          if (!array_key_exists($file, $patchsetinfo)) {
              return false;
          }

          // If both the linefrom and the lineto are empty, match
          if (empty($linefrom) and empty($lineto)) {
              return true;
          }

          // Let's see if $linefrom or $lineto matches any of the
          // lines intervals in the patchset
          foreach ($patchsetinfo[$file] as $interval) {
              if ($interval[0] <= $linefrom and $linefrom <= $interval[1]) {
                  return true;
              } else if ($interval[0] <= $lineto and $lineto <= $interval[1]) {
                  return true;
              }
          }
          return false;
      }

     /**
      * Load one patchset file into one array
      * with keys being the files and values
      * one array of (from, to) arrays
      */
     protected function load_patchset_file($file) {
         $results = array();
         $xmlcontents = file_get_contents($file);
         $xml = new SimpleXMLElement($xmlcontents);
         foreach ($xml->file as $file) {
             $linesarr = array();
             foreach ($file->lines as $line) {
                 $linesarr[] = array((int)$line['from'], (int)$line['to']);
             }
             $results[(string)$file['name']] = $linesarr;
         }
         return $results;
     }

    /**
     * Transform one checkstyle file into an smurf check
     */
    protected function process_cs($params, $file) {
        // Let's transform the cs file if present
        $file = $this->directory . '/' . $file;
        if (!is_readable($file)) {
            return null;
        }

        // read the file
        $xmlcontents = file_get_contents($file);
        if (empty($xmlcontents)) {
            return null;
        }
        $xml = new SimpleXMLElement($xmlcontents);

        // read the xslt
        $xslt = new XSLTProcessor();
        $xslcontents = file_get_contents('xslt/checkstyle2smurf.xsl');
        $xslt->importStylesheet(new SimpleXMLElement($xslcontents));

        // set params
        $xslt->setParameter('', $params);

        // conver to DOMDocument
        return $xslt->transformToDoc($xml);
    }
}
