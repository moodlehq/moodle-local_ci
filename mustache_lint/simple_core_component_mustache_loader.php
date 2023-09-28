<?php

class simple_core_component_mustache_loader extends Mustache_Loader_FilesystemLoader {

    protected $theme = null;
    /**
     * Constructor.
     */
    public function __construct($theme = null) {
        parent::__construct(''); // We need the constructor to have defined baseDir property to avoid php >= 8.1 warnings.
        $this->theme = $theme;
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

        if ($this->theme) {
            // The real mustache loader handles theme parents - we don't here for simplicity.
            $themedir = core_component::get_plugin_directory('theme', $this->theme);

            $themetemplate = $themedir . '/templates/' . $component . '/'. $templatename . '.mustache';
            if (file_exists($themetemplate)) {
                return $themetemplate;
            }
        }

        $compdirectory = core_component::get_component_directory($component);
        $path = $compdirectory . '/templates/' . $templatename . '.mustache';
        if (!file_exists($path)) {
            return false;
        }

        return $path;
    }
}
