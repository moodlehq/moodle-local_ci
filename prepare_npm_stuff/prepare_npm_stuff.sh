#!/usr/bin/env bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to install the DB
# $nodecmd: Optional, path to the node executable (global)
# $npmcmd: Optional, path to the npm executable (global)
# $gitcmd: Optional, path to the git executable
# $shifterversion: Optional, defaults to 0.4.6. Not installed if there is a package.json file (present in 29 and up)
# $recessversion: Optional, defaults to 1.1.9 (Important! it's the only legacy version working. Older ones
#    lead to empty results). Not installed if there is a package.json file (present in 29 and up)

# Let's be strict. Any problem leads to failure.
set -e

required="gitdir gitbranch"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "ERROR: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Important, this script is always run sourced from others, so it shouldn't define
# any shell variable also set/used by caller scripts. A clear example is the $mydir
# variable below, that was being set for caller script, leading to strange failures.
#
# In this case it was easy to fix, because this script doesn't use it, so getting rid
# of it was enough. But in general, avoid setting any widely used variable here.
#
# calculate some variables
#mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply some defaults.
shifterversion=${shifterversion:-0.4.6}
recessversion=${recessversion:-1.1.9}
nodecmd=${nodecmd:-node}
npmcmd=${npmcmd:-npm}
gitcmd=${gitcmd:-git}

# Check if we have nvm installed @ home.
export NVM_DIR="$HOME/.nvm"
if [[ ! -r "${NVM_DIR}/nvm.sh" ]];then
    # nvm not installed, let's install it with git
    echo "INFO: nvm not found, installing via git"
    $gitcmd clone --quiet https://github.com/nvm-sh/nvm.git "${NVM_DIR}"
fi

# Try to update to latest release (if git based installation only).
if [[ -d "${NVM_DIR}/.git" ]]; then
    # nvm installed via git, fetch updates
    cd "${NVM_DIR}"
    echo "INFO: nvm git installation found, updating to latest release"
    $gitcmd fetch --quiet --tags origin
    # Get latest nvm release and use it
    export NVM_VERSION=$($gitcmd describe --abbrev=0 --tags --match "v[0-9]*" $($gitcmd rev-list --tags --max-count=1))
    echo "INFO: using nvm version: ${NVM_VERSION}"
    $gitcmd checkout --quiet ${NVM_VERSION}
else
    echo "INFO: nvm installation is not git-based, updating skipped"
fi

# Move to base directory
cd ${gitdir}

if [[ -r ".nvmrc" ]]; then
    # Only if there is a .nvmrc file available
    echo "INFO: .nvmrc file found: $(<.nvmrc). Installing node..."
    # Source it, install and use the .nvmrc version
    source $NVM_DIR/nvm.sh --no-use
    echo "INFO: nvm version: $(nvm --version)"
    nvm install && nvm use
    echo "INFO: node installation completed"
else
    echo "INFO: .nvmrc not found, nvm install skipped"
fi

# Print nodejs and npm versions for informative purposes
if hash ${nodecmd} 2>/dev/null; then
    echo "INFO: node version: $(${nodecmd} --version)"
fi
if hash ${npmcmd} 2>/dev/null; then
    echo "INFO: npm version: $(${npmcmd} --version)"
fi

# Unconditionally remove any previous installed stuff.
# We always install from scratch. In caches we trust.
rm -fr ${gitdir}/node_modules

# Install general stuff only if there is a package.json file
if [[ -f ${gitdir}/package.json ]]; then

    echo "INFO: Installing npm stuff following package/shrinkwrap details"

    if ! hash ${npmcmd} 2>/dev/null; then
        echo "ERROR: npm not found in the system. Use .nvmrc OR install it in the PATH"
        exit 2
    fi

    # Always run npm install to keep our npm packages correct
    ${npmcmd} --no-color install

    # Verify that grunt-cli is available (locally), installing if missing
    if ! ${npmcmd} list --parseable | grep -q grunt-cli; then
        # Last chance, look for the binary itself.
        if [[ ! -x node_modules/.bin/grunt ]]; then
            echo "WARN: grunt binary not found. Installing it now"
            ${npmcmd} --no-color --no-save install grunt-cli
        fi
    fi

    # Verify that stylelint-checkstyle-formatter is available (locally), installing if missing
    if ! ${npmcmd} list --parseable | grep -q stylelint-checkstyle-formatter; then
        echo "WARN: stylelint-checkstyle-formatter package not found. Installing it now"
        ${npmcmd} --no-color --no-save install stylelint-checkstyle-formatter
    fi
else
    echo "ERROR: Something is wrong. Missing package.json"
fi

# Move back to base directory.
cd ${gitdir}

# Output information about installed binaries.
echo "INFO: Installation ended"
echo "INFO: Installed packages @ $(npm root)"
echo "INFO: (Contents of ${npmcmd} list --depth=1)"
for package in $(${npmcmd} list --depth=1 --parseable); do
    echo "INFO:    - Installed $(basename ${package})"
done
echo "============== END OF LIST =============="
