# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# We want to launch always a sqlsrv PHPUNIT
echo -n "PHPUnit (sqlsrv): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "SDEV.02 - Developer-requested PHPUnit" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=sqlsrv \
    -p PHPVERSION=${php_version} \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# Disabled for now, it's failing a lot :-(
# We want to launch always a Behat (latest, @app only) job
#echo -n "App tests (experimental): " >> "${resultfile}.jenkinscli"
#${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
#    -p REPOSITORY=${repository} \
#    -p BRANCH=${branch} \
#    -p DATABASE=pgsql \
#    -p PHPVERSION=${php_version} \
#    -p BROWSER=chrome \
#    -p BEHAT_TOTAL_RUNS=1 \
#    -p MOBILE_VERSION=latest \
#    -p INSTALL_PLUGINAPP=true \
#    -p TAGS=@app \
#    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (goutte) job
echo -n "Behat (goutte): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=${php_version} \
    -p BROWSER=goutte \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (firefox) job
echo -n "Behat (firefox): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "SDEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=${php_version} \
    -p BROWSER=firefox \
    -w >> "${resultfile}.jenkinscli" < /dev/null
