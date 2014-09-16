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

        // Process the cs output, weighting errors with 5 and warnings with 1
        $params = array(
            'title' => 'Coding style problems',
            'description' => 'This section shows the coding style problems detected in the code by phpcs',
            'url' => 'http://docs.moodle.org/dev/Coding_style',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 5,
            'warningweight' => 1);
        if ($node = $this->apply_xslt($params, $this->directory . '/cs.xml', 'checkstyle2smurf.xsl')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Process the docs output, weighting errors with 3 and warnings with 1
        $params = array(
            'title' => 'PHPDocs style problems',
            'description' => 'This section shows the phpdocs problems detected in the code by local_moodlecheck',
            'url' => 'http://docs.moodle.org/dev/Coding_style',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 3,
            'warningweight' => 1);
        if ($node = $this->apply_xslt($params, $this->directory . '/docs.xml', 'checkstyle2smurf.xsl')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Process the commits output, weighting errors with 3 and warnings with 1
        $params = array(
            'title' => 'Commit messages problems',
            'description' => 'This section shows the problems detected in the commit messages by the commits checker',
            'url' => 'https://docs.moodle.org/dev/Commit_cheat_sheet#Provide_clear_commit_messages',
            'codedir' => '', // We are storing the commit hashes so, nothing to trim from them.
            'errorweight' => 3,
            'warningweight' => 1);
        if ($node = $this->apply_xslt($params, $this->directory . '/commits.xml', 'checkstyle2smurf.xsl')) {
            if ($check = $node->getElementsByTagName('check')->item(0)) {
                $snode = $doc->importNode($check, true);
                $smurf->appendChild($snode);
            }
        }

        // Process the savepoints output, weighting errors with 50 and warnings with 10
        $params = array(
            'title' => 'Update savepoints problems',
            'description' => 'This sections shows problems detected with the handling of upgrade savepoints',
            'url' => 'http://docs.moodle.org/dev/Upgrade_API',
            'codedir' => dirname($this->directory) . '/',
            'errorweight' => 50,
            'warningweight' => 10);
        if ($node = $this->apply_xslt($params, $this->directory . '/savepoints.xml', 'checkstyle2smurf.xsl')) {
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
            case 'html':
                file_put_contents($this->directory . '/tmp.xml', $doc->saveXML());
                $result = $this->apply_xslt($params, $this->directory . '/tmp.xml', 'gargamel.xsl');
                unlink($this->directory . '/tmp.xml');
                return $result->saveXML();
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

          // If both the linefrom and the lineto are empty, match
          if (empty($linefrom) and empty($lineto)) {
              return true;
          }

          // If the file is not present in the patchset, no match
          if (!array_key_exists($file, $patchsetinfo)) {
              return false;
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
     * Apply a xslt transformation
     *
     * @param $params array of xlst params.
     * @param $file full path to the file to process.
     * @param $xsltfile transformation to sheet to apply (must exist in the "xslt" directory).
     * @return string contents transformed
     */
    protected function apply_xslt($params, $file, $xsltfile) {
        // Verify $file exists.
        if (!is_readable($file)) {
            return null;
        }
        // Verify $xslt exists
        if (!is_readable('xslt/' . $xsltfile)) {
            return null;
        }

        // Read $file.
        $xmlcontents = file_get_contents($file);
        if (empty($xmlcontents)) {
            return null;
        }
        $xml = new SimpleXMLElement($xmlcontents);

        // Read $xslt.
        $xslt = new XSLTProcessor();
        $xslcontents = file_get_contents('xslt/' . $xsltfile);
        $xslt->importStylesheet(new SimpleXMLElement($xslcontents));

        // Set $params.
        $xslt->setParameter('', $params);

        // Apply the transformations and return the results.
        return $xslt->transformToDoc($xml);
    }
}
