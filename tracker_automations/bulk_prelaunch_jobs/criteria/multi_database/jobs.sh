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
    if [[ -n ${phpunit_suite} ]]; then
        phpunit_options+=" --testsuite ${phpunit_suite}"
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
            -p TAGS=${phpunit_filter} \
            -p TESTSUITE=${phpunit_suite} \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi

# This is a behat-goutte jobtype, let's launch it.
if [[ "${jobtype}" == "behat-goutte" ]]; then
    # Loop over all the configured dbtypes.
    dbtypesarr=($(echo ${dbtypes} | tr ',' '\n'))
    for dbtype in "${dbtypesarr[@]}"; do
        dbtype=${dbtype//[[:blank:]]/}
        echo -n "Behat (goutte - boost and classic - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
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
            -p BROWSER=goutte \
            -p BEHAT_SUITE=ALL \
            -p TAGS="${final_tags}" \
            -p NAME="${behat_name}" \
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
        echo -n "Behat (firefox - boost - ${dbtype} / ${behat_options}): " >> "${resultfile}.jenkinscli"
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
            -p BROWSER=firefox \
            -p BEHAT_SUITE=default \
            -p TAGS="${final_tags}" \
            -p NAME="${behat_name}" \
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
            -p BROWSER=chrome \
            -p BEHAT_INCREASE_TIMEOUT=3 \
            -p MOBILE_VERSION=latest-test \
            -p INSTALL_PLUGINAPP=ci \
            -p TAGS="${final_tags}" \
            -p NAME="${behat_name}" \
            -p RUNNERVERSION=${runner} \
            -w >> "${resultfile}.jenkinscli" < /dev/null
    done
fi
