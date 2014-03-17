#!/bin/bash
# $composercmd: Path to the composer (usually installed globally in the CI server) executable
# $composerdirbase: Path to the directory where composer will be installed (--working-dir). branch name will be automatically added.
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $githuboauthtoken: Token for accessing gitub without limits.

# Let's be strict. Any problem will abort execution.
set +e

# Verify everything is set
required="composercmd composerdirbase gitdir gitbranch githuboauthtoken"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Calculate composer working directory and create it if needed.
composerdir=${composerdirbase}/${gitbranch}
mkdir -p ${composerdir}

# Copy composer.json file to composer directory.
cp ${gitdir}/composer.json ${composerdir}

# If there is not any "vendor" directory there, proceeed by installing, else updating.
if [[ -d ${composerdir}/vendor ]]; then
    ${composercmd} update --working-dir=${composerdir} --prefer-dist
else
    ${composercmd} config --global github-oauth.github.com ${githuboauthtoken}
    ${composercmd} install --working-dir=${composerdir} --prefer-dist
fi
# Optimize autoloader of installed stuff.
${composercmd} dump-autoload --optimize --working-dir=${composerdir}

# Add the bin directory to the PATH, so it can be used
export PATH=${composerdir}/vendor/bin:${PATH}

# And link it to dirroot/vendor as far as we have dependencies in tool_phpunit
# requiring vendor to be there, grrr.
ln -s ${composerdir}/vendor ${gitdir}/vendor
