<?php

/**
 * Helper to process JS and lint it.
 */
class js_helper {
    protected $js;
    protected $moodleroot;

    /**
     * Constructor.
     * @param string $moodleroot path to moodle $CFG->dirroot.
     */
    public function __construct($moodleroot) {
        $this->moodleroot = $moodleroot;
        $this->js = '';
    }

    /**
     * Renders and stores js for later processing.
     *
     * @param string $content The template content.
     * @param Mustache_LambdaHelper $helper Used to render nested mustache variables.
     */
    public function add_js($content, Mustache_LambdaHelper $helper) {
        $this->js .= $helper->render($content);
    }

    /**
     * Gets the path to eslint executable
     *
     * @return string|false Path to eslint or false if its not found.
     */
    protected function get_eslint_path() {
        $eslint = $this->moodleroot.'/node_modules/.bin/eslint';
        if (file_exists($eslint) && is_executable($eslint)) {
            return $eslint;
        }

        return false;
    }

    /**
     * Runs eslint against the js stored. Returns the json_decoded response
     * from the messages in http://eslint.org/docs/user-guide/formatters/#json
     *
     * @return array|false List of problem messages from eslint or false if we didn't run.
     */
    public function run_eslint() {
        if (empty($this->js)) {
            // Don't bother doing all the rest of the work, there is no JS.
            return [];
        }

        if (!$eslint = $this->get_eslint_path()) {
            // Eslint not installed.
            return false;
        }

        $pipes = [];
        $pipesspec = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
        ];

        $cmd = "$eslint --stdin --config {$this->moodleroot}/.eslintrc --format=json";
        $proc = proc_open($cmd, $pipesspec, $pipes);
        // Send the JS to stdin.
        fwrite($pipes[0], $this->js);
        fclose($pipes[0]);

        // Get the output.
        $response = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        proc_close($proc);

        $problems = json_decode($response);
        if ($problems === null) {
            // Not got valid json response.
            return false;
        }

        // We should only have problem messages for the one file passed.
        return $problems[0]->messages;
    }
}
