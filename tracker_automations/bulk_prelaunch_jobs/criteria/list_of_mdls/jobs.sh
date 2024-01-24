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
# TODO: Remove this once we have moved out from TAGS (to PHPUNIT_FILTER and BEHAT_TAGS).
if [[ -n ${phpunit_filter} ]] && [[ -n ${behat_tags} ]]; then
    echo "ERROR: Cannot use phpunit_filter and behat_tags together"
    exit 1
fi

# Calculate the PHPUnit options (filter, testsuite) to use.
phpunit_options=""
if [[ -n ${phpunit_filter} ]]; then
    phpunit_options="--filter ${phpunit_filter}"
fi
if [[ -n ${phpunit_testsuite} ]]; then
    phpunit_options+=" --testsuite ${phpunit_testsuite}"
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
        -p PHPUNIT_FILTER=${phpunit_filter} \
        -p PHPUNIT_TESTSUITE=${phpunit_testsuite} \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (BrowserKit (non-js)) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-nonjs" ]]; then
    echo -n "Behat (NonJS - boost and classic / ${behat_options}): " >> "${resultfile}.jenkinscli"
    final_tags=
    if [[ -n "${behat_tags}" ]]; then
        # Add the ~@javascript tag, because this is a non-js run.
        final_tags="${behat_tags}&&~@javascript"
    fi
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="BrowserKit (non-js)" \
        -p BEHAT_SUITE=ALL \
        -p BEHAT_TAGS="${final_tags}" \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch sometimes a Behat (Chrome (js) - boost) job.
if [[ "${jobtype}" == "behat-chrome" ]]; then
    echo -n "Behat (Chrome - boost / ${behat_options}): " >> "${resultfile}.jenkinscli"
    final_tags=
    if [[ -n "${behat_tags}" ]]; then
        # Add the @javascript tag, because this is a js run, and skip known chrome bug.
        final_tags="${behat_tags}&&@javascript&&~@skip_chrome_zerosize"
    fi
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Chrome (js)" \
        -p BEHAT_TAGS="${final_tags}" \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch sometimes a Behat (Chrome (js) - classic) job.
if [[ "${jobtype}" == "behat-chrome" ]]; then
    echo -n "Behat (Chrome - classic / ${behat_options}): " >> "${resultfile}.jenkinscli"
    final_tags=
    if [[ -n "${behat_tags}" ]]; then
        # Add the @javascript tag, because this is a js run, and skip known chrome bug.
        final_tags="${behat_tags}&&@javascript&&~@skip_chrome_zerosize"
    fi
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Chrome (js)" \
        -p BEHAT_SUITE=classic \
        -p BEHAT_TAGS="${final_tags}" \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (Firefox (js) - boost) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (Firefox - boost / ${behat_options}): " >> "${resultfile}.jenkinscli"
    final_tags=
    if [[ -n "${behat_tags}" ]]; then
        # Add the @javascript tag, because this is a js run.
        final_tags="${behat_tags}&&@javascript"
    fi
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Firefox (js)" \
        -p BEHAT_TAGS="${final_tags}" \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (Firefox (js) - classic) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-firefox" ]]; then
    echo -n "Behat (Firefox - classic / ${behat_options}): " >> "${resultfile}.jenkinscli"
    final_tags=
    if [[ -n "${behat_tags}" ]]; then
        # Add the @javascript tag, because this is a js run.
        final_tags="${behat_tags}&&@javascript"
    fi
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=${php_version} \
        -p BROWSER="Firefox (js)" \
        -p BEHAT_SUITE=classic \
        -p BEHAT_TAGS="${final_tags}" \
        -p NAME="${behat_name}" \
        -p RUNNERVERSION=${runner} \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch a Behat (latest-test, @app only) job
# only if the target branch is main.
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-all" ]] || [[ "${jobtype}" == "behat-app" ]]; then
    # Only for main or when behat-app is explicitly asked.
    if [[ ${target} == "main" ]] || [[ "${jobtype}" == "behat-app" ]]; then
        echo -n "App tests (stable app version) / ${behat_options}): " >> "${resultfile}.jenkinscli"
        # These are the default tags for any app run.
        final_tags="@app&&~@performance&&~@local_behatsnapshots&&~@ci_jenkins_skip"
        if [[ -n "${behat_tags}" ]]; then
            # Add the specified tags, if any to the default ones.
            final_tags="${final_tags}&&${behat_tags}"
        fi
        ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=pgsql \
            -p PHPVERSION=${php_version} \
            -p BROWSER="Chrome (js)" \
            -p BEHAT_INCREASE_TIMEOUT=4 \
            -p MOBILE_VERSION=latest-test \
            -p INSTALL_PLUGINAPP=ci \
            -p BEHAT_TAGS="${final_tags}" \
            -p NAME="${behat_name}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    fi
fi
