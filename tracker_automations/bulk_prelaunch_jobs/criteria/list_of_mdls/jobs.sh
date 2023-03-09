# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# Set the runner if not specified.
runner="${runner:-STABLE}"

# Some issue must be specified.
if [[ -z ${issueslist} ]]; then
    echo "Error: Need to specify one or multiple (comma separated) MDL issues in $issueslist"
    exit 1
fi

# We don't allow both phpunit_filter and behat_tags together
# (because they both use the very same TAGS env variable)
if [[ -n ${phpunit_filter} ]] && [[ -n ${behat_tags} ]]; then
    echo "ERROR: Cannot use phpunit_filter and behat_tags together"
    exit 1
fi

# Calculate the PHPUnit options (filter, testsuite) to use.
phpunit_options=""
if [[ -n ${phpunit_filter} ]]; then
    phpunit_options="--filter ${phpunit_filter}"
fi
if [[ -n ${phpunit_suite} ]]; then
    phpunit_options+=" --testsuite ${phpunit_suite}"
fi
phpunit_options="${phpunit_options:-complete}"

# Calculate the Behat options (tags, name) to use.
behat_options=""
if [[ -n ${behat_tags} ]]; then
    behat_options="--tags ${behat_tags}"
fi
if [[ -n ${behat_name} ]]; then
    behat_options+=" --name \"${behat_name}\""
fi
behat_options="${behat_options:-complete}"

echo "PHPUnit options: ${phpunit_options}"
echo "Behat options: ${behat_options}"

# We want to launch always a sqlsrv PHPUNIT
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "phpunit" ]]; then
    echo -n "PHPUnit (sqlsrv / ${phpunit_options}): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.02 - Developer-requested PHPUnit" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=sqlsrv \
        -p PHPVERSION=${php_version} \
        -p TAGS=${phpunit_filter} \
        -p TESTSUITE=${phpunit_suite} \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# Disabled for now, it's failing a lot :-(
# We want to launch always a Behat (latest, @app only) job
#if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-app" ]]; then
#echo -n "App tests (experimental): " >> "${resultfile}.jenkinscli"
#${jenkinsreq} "DEV.01 - Developer-requested Behat" \
#    -p REPOSITORY=${repository} \
#    -p BRANCH=${branch} \
#    -p DATABASE=pgsql \
#    -p PHPVERSION=${php_version} \
#    -p BROWSER=chrome \
#    -p BEHAT_TOTAL_RUNS=1 \
#    -p MOBILE_VERSION=latest \
#    -p INSTALL_PLUGINAPP=true \
#    -p TAGS=@app \
#    -p RUNNERVERSION=${runner} \
#    -w >> "${resultfile}.jenkinscli" < /dev/null
#fi

# We want to launch always a Behat (goutte) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-goutte" ]]; then
    echo -n "Behat (goutte - boost and classic / ${behat_options}): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER=goutte \
        -p BEHAT_SUITE=ALL \
        -p TAGS=${behat_tags} \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (firefox - boost) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (firefox - boost / ${behat_options}): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER=firefox \
        -p TAGS=${behat_tags} \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (firefox - classic) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (firefox - classic / ${behat_options}): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER=firefox \
        -p BEHAT_SUITE=classic \
        -p TAGS=${behat_tags} \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi
