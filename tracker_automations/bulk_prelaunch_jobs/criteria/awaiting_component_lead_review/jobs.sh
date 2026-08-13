# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# We want to launch always a sqlsrv PHPUNIT
echo -n "PHPUnit (sqlsrv): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "DEV.02 - Developer-requested PHPUnit" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=sqlsrv \
    -p PHPVERSION=${php_version} \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (BrowserKit (non-js)) job
echo -n "Behat (NonJS - ${allsuiteslabel}): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "DEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=${php_version} \
    -p BROWSER="BrowserKit (non-js)" \
    -p BEHAT_SUITE=ALL \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (Firefox (js) - boost) job
echo -n "Behat (Firefox - boost): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "DEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=${php_version} \
    -p BROWSER="Firefox (js)" \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch a Behat (Firefox (js) - classic) job
# only if the target branch still ships theme_classic.
if [[ ${classicsupported} == "true" ]]; then
    echo -n "Behat (Firefox - classic): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Firefox (js)" \
        -p BEHAT_SUITE=classic \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch a Behat (latest-test, @app only) job
# only if the target branch is main.
if [[ ${target} == "main" ]]; then
    echo -n "App tests (stable app version): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Chrome (js)" \
        -p SELVERSION='latest' \
        -p BEHAT_INCREASE_TIMEOUT=4 \
        -p MOBILE_VERSION=latest-test \
        -p INSTALL_PLUGINAPP=ci \
        -p BEHAT_TAGS="@app&&~@performance&&~@local_behatsnapshots&&~@ci_jenkins_skip" \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch a Jest job
# only if the target branch is main.
if [[ ${target} == "main" ]]; then
    echo -n "Jest: " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.03 - Developer-requested Jest" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p PHPVERSION=${php_version} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch a Rector job
# only if the target branch is main.
# Note that the job only supports a reduced set of PHP versions (8.4 and up),
# so we don't pass PHPVERSION and let the job use its own default.
if [[ ${target} == "main" ]]; then
    echo -n "Rector: " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.04 - Developer requested Rector" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi
