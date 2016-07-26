## How to add fixture here ##

1. Go to the jenkins build page e.g. https://integration.moodle.org/job/Precheck%20remote%20branch/22118/
2. Go to build artefacts / work
3. Download all files in zip
4. Extract the zip and rename as directory here
5. Remove the non-required files with `rm *.{zip,txt,files,diff}`

**Note**

The test fixtures depend on the files generated in `/var/lib/jenkins/git_repositories/prechecker/` - you will
need to rewrite the urls if it doesn't match that. (E.g. `sed -i.bak "s#/my/dir/#/var/lib/jenkins/git_repositories/prechecker#g" *.xml`)
