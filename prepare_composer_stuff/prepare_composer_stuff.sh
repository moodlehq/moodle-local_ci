#!/usr/bin/env bash
# $phpcmd: Path to the PHP CLI executable
# $composercmd: Path to the composer (usually installed globally in the CI server) executable
# $composerdirbase: Path to the directory where composer will be installed (--working-dir). branch name will be automatically added.
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $githuboauthtoken: Token for accessing gitub without limits.

# Let's be strict. Any problem will abort execution.
set -e

# Set the composer env variable so it always use the correct php when multiple are installed.
export PATH=$(dirname ${phpcmd}):${PATH}

# Verify everything is set
required="phpcmd composercmd composerdirbase gitdir gitbranch githuboauthtoken"
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
    echo "Updating composer packages @ ${composerdir}"
    ${composercmd} update --working-dir=${composerdir} --prefer-dist
else
    echo "Installing composer packages @ ${composerdir}"
    ${composercmd} config --global github-oauth.github.com ${githuboauthtoken}
    ${composercmd} install --working-dir=${composerdir} --prefer-dist
fi
# Optimize autoloader of installed stuff.
echo "Optimizing composer autoload @ ${composerdir}"
${composercmd} dump-autoload --optimize --working-dir=${composerdir}

# Add the bin directory to the PATH, so it can be used
export PATH=${composerdir}/vendor/bin:${PATH}

# And link it to dirroot/vendor as far as we have dependencies in tool_phpunit
# requiring vendor to be there, grrr.
echo "Linking ${composerdir}/vendor from ${gitdir}/vendor"
if [[ -L ${gitdir}/vendor ]]; then
    rm -f ${gitdir}/vendor
fi
ln -nfs ${composerdir}/vendor ${gitdir}/vendor
