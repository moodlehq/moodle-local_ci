# CI local plugin

[![Build Status](https://travis-ci.org/moodlehq/moodle-local_ci.svg?branch=master)](https://travis-ci.org/moodlehq/moodle-local_ci)

This local_ci plugin contains all the scripts needed
by Moodle CI servers to automate checks while
integration happens.

## Dependencies

+ Some checks require a MySQL, master-based site to be up and running.
+ Some checks require the installation of 3rd part tools (phpunit...).
+ Some checks require the presence of both local_codechecker and local_moodlecheck local plugins.
+ Visit [HQ-326](http://tracker.moodle.org/browse/HQ-326) for a step by step record about the installation of http://integration.moodle.org:8080 It can be useful to know what to install and the real php/pear dependencies.

## TODO

+ Complete the documentation.
+ Document each check properly.

## Self-versions

+ 20121112 - Eloy - Initial version of this README.md.
