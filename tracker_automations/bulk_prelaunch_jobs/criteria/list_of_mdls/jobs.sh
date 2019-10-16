# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# DISABLED FOR NOW, AS FAR AS WE AREN'T PLENTY OF FREE SLOTS
# Better concentrate on Behat runs for now and save some workers.
# We want to launch always an Oracle PHPUNIT
#echo -n "PHPUnit (oracle): " >> "${resultfile}.jenkinscli"
#${jenkinsreq} "DEV.02 - Developer-requested PHPUnit" \
#    -p REPOSITORY=${repository} \
#    -p BRANCH=${branch} \
#    -p DATABASE=oci \
#    -p PHPVERSION=7.2 \
#    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (goutte) job
echo -n "Behat (goutte): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "DEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=7.2 \
    -p BROWSER=goutte \
    -w >> "${resultfile}.jenkinscli" < /dev/null

# We want to launch always a Behat (chrome) job
echo -n "Behat (chrome): " >> "${resultfile}.jenkinscli"
${jenkinsreq} "DEV.01 - Developer-requested Behat" \
    -p REPOSITORY=${repository} \
    -p BRANCH=${branch} \
    -p DATABASE=pgsql \
    -p PHPVERSION=7.2 \
    -p BROWSER=chrome \
    -w >> "${resultfile}.jenkinscli" < /dev/null
