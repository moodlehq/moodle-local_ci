<?php

class simple_core_component_mustache_loader extends Mustache_Loader_FilesystemLoader {

    /**
     * Provide a default no-args constructor (we don't really need anything).
     */
    public function __construct() {
    }

    /**
     * Helper function for getting a Mustache template file name.
     * Uses the leading component to restrict us specific directories.
     *
     * @param string $name
     * @return string Template file name
     */
    protected function getFileName($name) {
        if (strpos($name, '/') === false) {
            // Silently ignore.
            return false;
        }

        list($component, $templatename) = explode('/', $name, 2);
        $compdirectory = core_component::get_component_directory($component);
        $path = $compdirectory . '/templates/' . $templatename . '.mustache';
        if (!file_exists($path)) {
            return false;
        }

        return $path;
    }
}
