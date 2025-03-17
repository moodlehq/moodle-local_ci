# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# Set the runner if not specified.
runner="${runner:-STABLE}"

# These are the valid database types.
validdbtypesarr=(pgsql mysqli mariadb sqlsrv oci)

# Some issue must be specified.
if [[ -z ${issueslist} ]]; then
    echo "Error: Need to specify one or multiple (comma separated) MDL issues in $issueslist"
    exit 1
fi

# Only one branch is allowed
if [[ "${cf_branches}" =~ , ]]; then
    echo "Error: Only one branch (name:tracker_field:php_version format) can be specified. Multiple detected"
    exit 1
fi

# Some databases must be specified (comma separated list). And we have to
# validate they are correct ones (pgsql, mysqli, mariadb, sqlsrv, oci).
if [[ -z ${dbtypes} ]]; then
    echo "Error: Need to specify a comma separated list of db types (pgsql, mysqli, mariadb, sqlsrv, oci)"
    exit 1
else
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        if [[ ! " ${validdbtypesarr[*]} " =~ " ${dbtype} " ]]; then
            echo "Error: Invalid db type (${dbtype}) found. Allowed values are: pgsql, mysqli, mariadb, sqlsrv, oci"
            exit 1
        fi
    done
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
if [[ $jobtype =~ ^phpunit ]]; then # Only if the job type is phpunit.
    if [[ -n ${phpunit_filter} ]]; then
        phpunit_options="--filter ${phpunit_filter}"
    fi
    if [[ -n ${phpunit_testsuite} ]]; then
        phpunit_options+=" --testsuite ${phpunit_testsuite}"
    fi
    phpunit_options="${phpunit_options:-complete}"
    echo "PHPUnit options: ${phpunit_options}"
fi

# Calculate the Behat options (tags, name) to use.
if [[ $jobtype =~ ^behat ]]; then # Only if the job type is behat.
    behat_options=""
    if [[ -n ${behat_tags} ]]; then
        behat_options="--tags ${behat_tags}"
    fi
    if [[ -n ${behat_name} ]]; then
        behat_options+=" --name \"${behat_name}\""
    fi
    behat_options="${behat_options:-complete}"
    echo "Behat options: ${behat_options}"
fi

# Show the configured databases:
echo "Databases: ${dbtypes}"

# Depending of the job type, launch the corresponding DEV jobs.

# This is a phpunit jobtype, let's launch it.
if [[ "${jobtype}" == "phpunit" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "PHPUnit (${dbtype} / ${phpunit_options}): " >> "${resultfile}.jenkinscli"
        ${jenkinsreq} "DEV.02 - Developer-requested PHPUnit" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=${dbtype} \
            -p PHPVERSION=${php_version} \
            -p PHPUNIT_FILTER=${phpunit_filter} \
            -p PHPUNIT_TESTSUITE=${phpunit_testsuite} \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi

# This is a behat-nonjs jobtype, let's launch it.
if [[ "${jobtype}" == "behat-nonjs" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "Behat (NonJS - boost and classic - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
        final_tags=
        if [[ -n "${behat_tags}" ]]; then
            # Add the ~@javascript tag, because this is a non-js run.
            final_tags="${behat_tags}&&~@javascript"
        fi
        ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=${dbtype} \
            -p PHPVERSION=${php_version} \
            -p BROWSER="BrowserKit (non-js)" \
            -p BEHAT_SUITE=ALL \
            -p BEHAT_TAGS="${final_tags}" \
            -p BEHAT_NAME="${behat_name}" \
            -p BEHAT_INIT_ARGS="${behat_init_args}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi

# This is a behat-chrome jobtype, let's launch it.
if [[ "${jobtype}" == "behat-chrome" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "Behat (Chrome - boost - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
        final_tags=
        if [[ -n "${behat_tags}" ]]; then
            # Add the @javascript tag, because this is a js run, and skip known chrome bug.
            final_tags="${behat_tags}&&@javascript&&~@skip_chrome_zerosize"
        fi
        ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=${dbtype} \
            -p PHPVERSION=${php_version} \
            -p BROWSER="Chrome (js)" \
            -p BEHAT_SUITE=default \
            -p BEHAT_TAGS="${final_tags}" \
            -p BEHAT_NAME="${behat_name}" \
            -p BEHAT_INIT_ARGS="${behat_init_args}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi

# This is a behat-firefox jobtype, let's launch it.
if [[ "${jobtype}" == "behat-firefox" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "Behat (Firefox - boost - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
        final_tags=
        if [[ -n "${behat_tags}" ]]; then
            # Add the @javascript tag, because this is a js run.
            final_tags="${behat_tags}&&@javascript"
        fi
        ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=${dbtype} \
            -p PHPVERSION=${php_version} \
            -p BROWSER="Firefox (js)" \
            -p BEHAT_SUITE=default \
            -p BEHAT_TAGS="${final_tags}" \
            -p BEHAT_NAME="${behat_name}" \
            -p BEHAT_INIT_ARGS="${behat_init_args}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi

# This is a behat-app jobtype, let's launch it.
if [[ "${jobtype}" == "behat-app" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "App tests (stable app version) - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
        # These are the default tags for any app run.
        final_tags="@app&&~@performance&&~@local_behatsnapshots&&~@ci_jenkins_skip"
        if [[ -n "${behat_tags}" ]]; then
            # Add the specified tags, if any to the default ones.
            final_tags="${final_tags}&&${behat_tags}"
        fi
        ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
            -p REPOSITORY=${repository} \
            -p BRANCH=${branch} \
            -p DATABASE=${dbtype} \
            -p PHPVERSION=${php_version} \
            -p BROWSER="Chrome (js)" \
            -p BEHAT_INCREASE_TIMEOUT=4 \
            -p MOBILE_VERSION=latest-test \
            -p INSTALL_PLUGINAPP=ci \
            -p BEHAT_TAGS="${final_tags}" \
            -p BEHAT_NAME="${behat_name}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi
