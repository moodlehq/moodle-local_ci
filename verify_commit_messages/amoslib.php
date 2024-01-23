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
 * We reimplement this so we can copy and paste code from local_amos/mlanglib.php
 */
class mlang_version {
    // Stub..
};

// Define some constants to alloow copy and pasting of code without warnings..
define('PARAM_PATH',     'path');
define('PARAM_STRINGID',    'stringid');
// We don't care about this for parsing purposes.
function clean_param($param, $type) {
    return $param;
}

/**
 * Parser for AMOS script, butchered from  https://github.com/moodlehq/moodle-local_amos/blob/master/mlanglib.php
 * This is an exact copy of execute() extract_script_from_text() and legacy_component_name() from that file, see the marker
 * below where copy/paste of code starts. The code above is to allow us copy and paste thos functions.
 */
class amos_script_parser {

    const STATUS_OK = 0;
    const STATUS_WARN = 1;
    const STATUS_SYNTAX_ERROR = 2;
    const STATUS_UNKNOWN_INSTRUCTION = 3;

    /**
     * Validate a commit message for amos comamnds.
     *
     * @param string $text the commit message text
     * @param string $filesmodified comma seperated list of files modified by the commit
     * @return int the number of problems found
     */
    public static function validate_commit_message($text, $filesmodified) {
        if (!preg_match('/(AMOS\s+(BEGIN|START)|AMOS\s+END)/', $text, $amosmatches)) {
            // No sign of amos command.
            return 0;
        }

        $instructions = self::extract_script_from_text($text);

        if (empty($instructions)) {
            self::print_error("No valid commands parsed, but '{$amosmatches[1]}' in commit. Syntax is wrong.");
            return 1; // 1 problem found.
        }

        if (!self::commit_would_be_detected_by_amos($filesmodified)) {
            self::print_error("Commands parsed in commit message, but no lang file was modified.");
            return 1; // 1 problem found.
        }

        $version = new mlang_version();
        $problems = 0;
        foreach ($instructions as $instruction) {
            $code = self::execute($instruction, $version);
            if ($code > self::STATUS_OK) {
                self::print_error("Instruction not understood '$instruction'");
                $problems++;
            }
        }
        return $problems;
    }

    /**
     * Determines if a commit would be detected by AMOS based on the
     * files modified in the commit.
     *
     * @param string $filesmodified comma seperated list of files
     * @return bool true if the commit would be detected
     */
    public static function commit_would_be_detected_by_amos($filesmodified) {
        // I'm sure I could do this more efficiently with a single regular
        // expression, but I decided to KISS.
        foreach (explode(',', $filesmodified) as $filepath) {
            if (preg_match('|lang/en/\w*\.php|', $filepath)) {
                return true;
            }
        }
        return false;
    }

    public static function print_error($message) {
        self::print_message($message, 'error');
    }

    public static function print_message($message, $severity = 'info') {
        global $COMMIT;
        echo "{$COMMIT}*{$severity}*AMOS - {$message}\n";
    }

    /**
     * Copy one string to another at the given version branch for all languages in the repository
     *
     * Deleted strings are not copied. If the target string already exists (and is not deleted), it is
     * not overwritten - compare with {@link self::forced_copy_string()}
     *
     * @param mlang_version $version to execute copying on
     * @param string $fromstring source string identifier
     * @param string $fromcomponent source component name
     * @param string $tostring target string identifier
     * @param string $tocomponet target component name
     * @param int $timestamp effective timestamp of the copy, null for now
     * @return mlang_stage to be committed
     */
    protected static function copy_string(mlang_version $version, $fromstring, $fromcomponent, $tostring, $tocomponent, $timestamp=null) {
        self::print_message("String to be copied: $fromstring/$fromcomponent to $tostring/$tocomponent");
        return self::STATUS_OK;
    }

    /**
     * Copy one string to another at the given version branch for all languages in the repository
     *
     * Deleted strings are not copied. The target string is always overwritten, even if it already exists
     * or it is deleted - compare with {@link self::copy_string()}
     *
     * @param mlang_version $version to execute copying on
     * @param string $fromstring source string identifier
     * @param string $fromcomponent source component name
     * @param string $tostring target string identifier
     * @param string $tocomponet target component name
     * @param int $timestamp effective timestamp of the copy, null for now
     * @return mlang_stage to be committed
     */
    protected static function forced_copy_string(mlang_version $version, $fromstring, $fromcomponent, $tostring, $tocomponent, $timestamp=null) {
        self::print_message("String to be force copied: $fromstring/$fromcomponent to $tostring/$tocomponent");
        return self::STATUS_OK;
    }

    /**
     * Move the string to another at the given version branch for all languages in the repository
     *
     * Deleted strings are not moved. If the target string already exists (and is not deleted), it is
     * not overwritten.
     *
     * @param mlang_version $version to execute moving on
     * @param string $fromstring source string identifier
     * @param string $fromcomponent source component name
     * @param string $tostring target string identifier
     * @param string $tocomponet target component name
     * @param int $timestamp effective timestamp of the move, null for now
     * @return mlang_stage to be committed
     */
    protected static function move_string(mlang_version $version, $fromstring, $fromcomponent, $tostring, $tocomponent, $timestamp=null) {
        self::print_message("String to be moved: $fromstring/$fromcomponent to $tostring/$tocomponent");
        return self::STATUS_OK;
    }

    /**
     * Migrate help file into a help string if such one does not exist yet
     *
     * This is a temporary method and will be dropped once we have all English helps migrated. It does not do anything
     * yet. It is intended to be run once upon a checkout of 1.9 language files prepared just for this purpose.
     *
     * @param mixed         $helpfile
     * @param mixed         $tostring
     * @param mixed         $tocomponent
     * @param mixed         $timestamp
     * @return mlang_stage
     */
    protected static function migrate_helpfile($version, $helpfile, $tostring, $tocomponent, $timestamp=null) {
        self::print_message("Helpfile to be moved from $helpfile to $tostring/$tocomponent");
        return self::STATUS_OK;
    }

    // -----------------------------------------------------------------
    // NOTE: The code following this line is directly copied taken from
    // moodle-local_amos/mlanglib.phop unmodified.
    // -----------------------------------------------------------------

    /**
     * Given a text, extracts AMOS script lines from it as array of commands
     *
     * See {@link http://docs.moodle.org/dev/Languages/AMOS} for the specification
     * of the script. Basically it is a block of lines starting with "AMOS BEGIN" line and
     * ending with "AMOS END" line. "AMOS START" is an alias for "AMOS BEGIN". Each instruction
     * in the script must be on a separate line.
     *
     * @param string $text
     * @return array of the script lines
     */
    public static function extract_script_from_text($text) {
        if (!preg_match('/^.*\bAMOS\s+(BEGIN|START)\s+(.+)\s+AMOS\s+END\b.*$/sm', $text, $matches)) {
            return array();
        }
        // collapse all whitespace into single space
        $script = preg_replace('/\s+/', ' ', trim($matches[2]));
        // we need explicit list of known commands so that this parser can handle onliners well
        $cmds = array('MOV', 'CPY', 'FCP', 'HLP', 'REM');
        // put new line character before every known command
        $cmdsfrom = array();
        $cmdsto   = array();
        foreach ($cmds as $cmd) {
            $cmdsfrom[] = "$cmd ";
            $cmdsto[]   = "\n$cmd ";
        }
        $script = str_replace($cmdsfrom, $cmdsto, $script);
        // make array of non-empty lines
        $lines = array_filter(array_map('trim', explode("\n", $script)));
        return array_values($lines);
    }

    /**
     * Executes the given instruction
     *
     * TODO AMOS script uses the new proposed component naming style, also known as frankenstyle. AMOS repository,
     * however, still uses the legacy names of components. Therefore we are translating new notation into the legacy
     * one here. This may change in the future.
     *
     * @param string $instruction in form of 'CMD arguments'
     * @param mlang_version $version strings branch to execute instruction on
     * @param int $timestamp effective time of the execution
     * @return int|mlang_stage mlang_stage to commit, 0 if success and there is nothing to commit, error code otherwise
     */
    public static function execute($instruction, mlang_version $version, $timestamp=null) {
        $spcpos = strpos($instruction, ' ');
        if ($spcpos === false) {
            $cmd = trim($instruction);
            $arg = null;
        } else {
            $cmd = trim(substr($instruction, 0, $spcpos));
            $arg = trim(substr($instruction, $spcpos + 1));
        }
        switch ($cmd) {
            case 'CPY':
                // CPY [sourcestring,sourcecomponent],[targetstring,targetcomponent]
                if (preg_match('/\[(.+),(.+)\]\s*,\s*\[(.+),(.+)\]/', $arg, $matches)) {
                    array_map('trim', $matches);
                    $fromcomponent = self::legacy_component_name($matches[2]);
                    $tocomponent = self::legacy_component_name($matches[4]);
                    if ($fromcomponent and $tocomponent) {
                        return self::copy_string($version, $matches[1], $fromcomponent, $matches[3], $tocomponent, $timestamp);
                    } else {
                        return self::STATUS_SYNTAX_ERROR;
                    }
                } else {
                    return self::STATUS_SYNTAX_ERROR;
                }
                break;
            case 'FCP':
                // FCP [sourcestring,sourcecomponent],[targetstring,targetcomponent]
                if (preg_match('/\[(.+),(.+)\]\s*,\s*\[(.+),(.+)\]/', $arg, $matches)) {
                    array_map('trim', $matches);
                    $fromcomponent = self::legacy_component_name($matches[2]);
                    $tocomponent = self::legacy_component_name($matches[4]);
                    if ($fromcomponent and $tocomponent) {
                        return self::forced_copy_string($version, $matches[1], $fromcomponent, $matches[3], $tocomponent, $timestamp);
                    } else {
                        return self::STATUS_SYNTAX_ERROR;
                    }
                } else {
                    return self::STATUS_SYNTAX_ERROR;
                }
                break;
            case 'MOV':
                // MOV [sourcestring,sourcecomponent],[targetstring,targetcomponent]
                if (preg_match('/\[(.+),(.+)\]\s*,\s*\[(.+),(.+)\]/', $arg, $matches)) {
                    array_map('trim', $matches);
                    $fromcomponent = self::legacy_component_name($matches[2]);
                    $tocomponent = self::legacy_component_name($matches[4]);
                    if ($fromcomponent and $tocomponent) {
                        return self::move_string($version, $matches[1], $fromcomponent, $matches[3], $tocomponent, $timestamp);
                    } else {
                        return self::STATUS_SYNTAX_ERROR;
                    }
                } else {
                    return self::STATUS_SYNTAX_ERROR;
                }
                break;
            case 'HLP':
                // HLP feedback/preview.html,[preview_hlp,mod_feedback]
                if (preg_match('/(.+),\s*\[(.+),(.+)\]/', $arg, $matches)) {
                    array_map('trim', $matches);
                    $helpfile = clean_param($matches[1], PARAM_PATH);
                    $tocomponent = self::legacy_component_name($matches[3]);
                    $tostring = $matches[2];
                    if ($tostring !== clean_param($tostring, PARAM_STRINGID)) {
                        return self::STATUS_SYNTAX_ERROR;
                    }
                    if ($helpfile and $tocomponent and $tostring) {
                        return self::migrate_helpfile($version, $helpfile, $tostring, $tocomponent, $timestamp);
                    } else {
                        return self::STATUS_SYNTAX_ERROR;
                    }
                } else {
                    return self::STATUS_SYNTAX_ERROR;
                }
                break;
            case 'REM':
                // todo send message to subscribed users
                return self::STATUS_OK;
                break;
                // WARNING: If a new command is added here, it must be also put into the list of known
                // commands in self::extract_script_from_text(). It is not nice but we use new line
                // as the delimiter and git may strip new lines if the script is part of the subject line.
            default:
                return self::STATUS_UNKNOWN_INSTRUCTION;
        }
    }

    /**
     * Given a newstyle component name (aka frankenstyle), returns the legacy style name
     *
     * @param string $newstyle name like core, core_admin, mod_workshop or auth_ldap
     * @return string|false legacy style like moodle, admin, workshop or auth_ldap, false in case of error
     */
    protected static function legacy_component_name($newstyle) {

        $newstyle = trim($newstyle);

        // See {@link PARAM_COMPONENT}.
        if (!preg_match('/^[a-z][a-z0-9]*(_[a-z][a-z0-9_]*)?[a-z0-9]+$/', $newstyle)) {
            return false;
        }

        if (strpos($newstyle, '__') !== false) {
            return false;
        }

        if ($newstyle == 'core') {
            return 'moodle';
        }

        if (substr($newstyle, 0, 5) == 'core_') {
            return substr($newstyle, 5);
        }

        if (substr($newstyle, 0, 4) == 'mod_') {
            return substr($newstyle, 4);
        }

        return $newstyle;
    }
}
