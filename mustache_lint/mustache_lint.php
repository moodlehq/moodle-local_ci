<?php
// This file is part of local_ci - https://github.com/moodlehq/moodle-local_ci
//
// local_ci is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// local_ci is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with local_ci.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Lint mustache templates.
 *
 * @category   ci
 * @package    local_ci
 * @copyright  2016 Dan Poltawski
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

require_once(__DIR__.'/../phplib/clilib.php');
require_once(__DIR__.'/../vendor/autoload.php');

list($options, $unrecognized) = cli_get_params(
    ['help' => false, 'filename' => '', 'validator' => '', 'basename' => ''],
    ['h' => 'help', 'f' => 'filename', 'v' => 'validator', 'b' => 'basename']);

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_error("Unrecognised options:\n{$unrecognized}\n Please use --help option.");
}

if ($options['help']) {
    $help =
"Check a Moodle mustache template.

Options:
-h, --help            Print out this help
-f, --filename        Path to file
-v, --validator       Validator URL (e.g. https://html5.validator.nu/ or http://localhost:8080/)
-b, --basename        Full path to the moodle base dir
";
    echo $help;
    exit(0);
}

if (empty($options['filename']) || empty($options['validator']) || empty($options['basename'])) {
    cli_error('--filename or --validator or --basename missing. Use --help to get more info.');
}

$VALIDATOR = $options['validator'];
$FILENAME = $options['filename'];
$WARNINGS = false;

if (!file_exists($FILENAME)) {
    echo "$FILENAME does not exist\n";
    exit(1);
}

if (!load_core_component_from_moodle($options['basename'])) {
    echo "Could not load core_component from dirroot: {$options['basename']}\n";
    exit(1);
}

if (strpos($FILENAME, $CFG->dirroot) !== 0) {
    echo "File path passed ($FILENAME) is not within basename ({$CFG->dirroot})\n";
    exit(1);
}

require_once(__DIR__.'/simple_core_component_mustache_loader.php');
require_once(__DIR__.'/js_helper.php');

$templatecontent = file_get_contents($FILENAME);
$theme = get_theme_from_template_path($FILENAME);
$jshelper = new js_helper($CFG->dirroot);
$mustache = new Mustache_Engine([
    'pragmas' => [Mustache_Engine::PRAGMA_BLOCKS],
    'helpers' => [ // Emulate some helpers for html validation purposes.
        'str' => function($text) { return "[[$text]]"; },
        'pix' => function($text) { return "<img src='pix-placeholder.png' alt='$text'>"; },
        'uniqid' => function() { return "would-be-a-uniqid"; },
        'quote' => function($text, $helper) {
            $content = $helper->render(trim($text));
            $content = str_replace('"', '\\"', $content);
            $content = preg_replace('([{}]{2,3})', '{{=<% %>=}}${0}<%={{ }}=%>', $content);
            return '"' . $content . '"';
        },
        'js' => [$jshelper, 'add_js'],
    ],
    'partials_loader' => new simple_core_component_mustache_loader($theme),
]);

$content = '';
try {
    $example = extract_example_from_template($templatecontent);
    $content = $mustache->render($templatecontent, $example);
} catch (exception $e) {
    print_problem('ERROR', 'Mustache syntax exception: '.$e->getMessage());
    exit(1);
}

if (empty($content)) {
    // This probably is related to a partial or so on. Best to avoid raising an error.
    print_message('INFO', 'Template produced no content');
} else {
    check_html_validation($content);
}

$eslintproblems = $jshelper->run_eslint();
if ($eslintproblems === false) {
    // Not an error situation for now, because we might run in situations
    // where npm dependencies including eslint are not installed.
    print_message('INFO', 'ESLint did not run');
} else {
    print_eslint_problems($eslintproblems);
}

if (!$WARNINGS) {
    print_message('OK', 'Mustache rendered html succesfully');
    exit(0);
} else {
    exit(1);
}

/**
 * Extracts the example context data from a template,
 * mostly copies the approach from the js in tool_templatelibrary.
 *
 * @param string $content the raw template as string.
 * @return mixed json_decoded data or false if no example found.
 * @throws exception if json fails to parse
 */
function extract_example_from_template($content) {
    $docs = '';
    preg_match_all('/{{!([\s\S]*?)}}/', $content, $sections);
    foreach ($sections[0] as $section) {
        // Do a bit of similar stuff as template lib to strip {{! and }}.
        $section = trim($section);
        $pos = strpos($section, '@template');
        if ($pos !== false) {
            $docs = substr($section, $pos, -2);
            break;
        }
    }

    if (empty($docs)) {
        print_problem('WARNING', 'Example context missing (@template section not found.)');
        return [];
    }

    if (!preg_match('/Example context \(json\):([\s\S]*)/', $docs, $matches)) {
        print_problem('WARNING', 'Example context missing.');
        return [];
    }

    $json = trim($matches[1]);
    $exampledata = json_decode($matches[1]);
    if ($exampledata !== null) {
        return $exampledata;
    }

    if (function_exists('json_last_error_msg')) {
        $lasterror = json_last_error_msg();
    } else {
        // Fall back to numeric error for older PHP version.
        $lasterror = json_last_error();
    }

    throw new Exception("Example context JSON is unparsable, fails with: $lasterror");
}

function print_problem($severity, $message) {
    global $WARNINGS;
    $WARNINGS = true;

    print_message($severity, $message);
}

function print_message($severity, $mesage) {
    global $FILENAME;

    echo "$FILENAME - $severity: $mesage\n";
}

/**
 * Wrap the template content in a html5 wrapper and validate it
 */
function check_html_validation($content) {
    if (strpos($content, '<head>') === false) {
        // Primative detection if we have full html body, if not, wrap it.
        // (This isn't bulletproof, obviously).
        $wrappedcontent = "<!DOCTYPE html><head><title>Validate</title></head><body>\n{$content}\n</body></html>";
    } else {
        $wrappedcontent = $content;
    }
    $response = validate_html($wrappedcontent);

    if (!$response || !isset($response->messages)) {
        print_problem('WARNING', 'Problem calling HTML validator - please report bug to integration team.');
        return;
    }

    if (empty($response->messages)) {
        // All good!
        return;
    }

    foreach ($response->messages as $problem) {
        //TODO: Sure would be nice if we could 'guess' a more accurate line number here..
        $context = str_replace("\n", '', $problem->extract);
        $message = "HTML Validation {$problem->type}, line {$problem->lastLine}: {$problem->message} ({$context})";
        print_problem('WARNING', $message);
    }
}

/**
 * Print out problems from eslint.
 * @param array $problems from eslint
 */
function print_eslint_problems($problems) {
    foreach ($problems as $problem) {
        // Remove the leading indentation..
        $problem->source = trim($problem->source);
        if (preg_match('/Parsing error:/', $problem->message)) {
            // Treat eslint parse errors specially, because they likely indicate
            // invalid example context rather than a real 'error'.
            print_problem('WARNING', "Missing example context? ESLint {$problem->message} ( {$problem->source} ), Line {$problem->line}");
            continue;
        }

        if ($problem->severity == 2) {
            $severity = 'ERROR';
        } else {
            $severity = 'WARNING';
        }
        $message = "ESLint [{$problem->ruleId}]: {$problem->message} ( {$problem->source} ), Line: {$problem->line} Column: {$problem->column}";
        print_problem($severity, $message);
    }
}

/**
 * Call the html validator with example content
 * @return mixed false if a problem occured or the response from validator
 */
function validate_html($content) {
    global $VALIDATOR;

    $ch = curl_init("$VALIDATOR?out=json");
    curl_setopt($ch, CURLOPT_USERAGENT, 'moodle/local_ci validator 0.1');
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-type: text/html; charset=utf-8']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FAILONERROR, true);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $content);
    $response = curl_exec($ch);
    $info = curl_getinfo($ch);
    curl_close($ch);

    if ($info['http_code'] !== 200) {
        return false; // Can't run html validator right now..
    }

    return json_decode($response);
}

/**
 * If the template path passed is part of a theme, returns the theme name.
 *
 * @param string $templatepath The path to the template.
 * @return string|null theme name or null if template not part of theme.
 */
function get_theme_from_template_path($templatepath) {
    global $CFG;

    $regexp = '#'.preg_quote($CFG->dirroot, '#').'/theme/([^/]+)/.*#';
    if (preg_match($regexp, $templatepath, $matches)) {
        return $matches[1];
    }

    return null;
}
