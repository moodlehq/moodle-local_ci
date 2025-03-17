# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# Set the runner if not specified.
runner="${runner:-STABLE}"

# We want to launch always a sqlsrv PHPUNIT
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "phpunit" ]]; then
    echo -n "PHPUnit (sqlsrv): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.02 - Developer-requested PHPUnit" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=sqlsrv \
        -p PHPVERSION=${php_version} \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (BrowserKit (non-js)) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-nonjs" ]]; then
    echo -n "Behat (NonJS - boost and classic): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="BrowserKit (non-js)" \
        -p BEHAT_SUITE=ALL \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch sometimes a Behat (Chrome (js) - boost) job.
if [[ "${jobtype}" == "behat-chrome" ]]; then
    echo -n "Behat (Chrome - boost): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Chrome (js)" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch sometimes a Behat (Chrome (js) - classic) job.
if [[ "${jobtype}" == "behat-chrome" ]]; then
    echo -n "Behat (Chrome - classic): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Chrome (js)" \
        -p BEHAT_SUITE=classic \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (Firefox (js) - boost) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (Firefox - boost): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Firefox (js)" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (Firefox (js) - classic) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (Firefox -classic): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Firefox (js)" \
        -p BEHAT_SUITE=classic \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch a Behat (latest-test, @app only) job
# only if the target branch is main.
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-app" ]]; then
    # Only for main or when behat-app is explicitly asked.
    if [[ ${target} == "main" ]] || [[ "${jobtype}" == "behat-app" ]]; then
        echo -n "App tests (stable app version): " >> "${resultfile}.jenkinscli"
        ${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=pgsql \
            -p PHPVERSION=${php_version} \
            -p BROWSER="Chrome (js)" \
            -p BEHAT_INCREASE_TIMEOUT=4 \
            -p MOBILE_VERSION=latest-test \
            -p INSTALL_PLUGINAPP=ci \
            -p TAGS="@app&&~@performance&&~@local_behatsnapshots&&~@ci_jenkins_skip" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    fi
fi
