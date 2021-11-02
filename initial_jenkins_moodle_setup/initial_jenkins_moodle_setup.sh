#!/usr/bin/env bash -e +x
# This script must be executed by the "jenkins" user
# (manually or from jenkins) in order to get the initial
# installation of Jenkins + Moodle ready.
#
# It's safe to execute it multiple times because all the
# steps are checked before execution.
#
# It's supposed to be a bash script.
#
# Requirements:
#   - one jenkins instance
#   - git
#   - mysql admin access (create anything)
#   - php-cli
#
# Variables (defined here for manual execution or
# as parameters if executed as Jenkins job):
#   - basedir: Base directory of jenkins.
#   - gitdir: Directory, under basedir, where all persistent git repos will reside.
#   - datadir: Directory, under basedir, where different persistent data will reside.
#   - moodledir: Directory, under gitdir, where the moodle CI site will reside.
#   - moodledatadir: Directory, under datadir, where the moodle CI site moodledata will reside.
#   - gitcmd: Path to git executable.
#   - mysqlcmd: Path to mysql executable.
#   - phpcmd: Path to php-cli executable.
#   - mysqladminuser: MySQL admin user (in charge of creating other users).
#   - mysqladminpass: MySQL admin password.
#   - mysqlmoodleuser: MySQL moodle_ci_site owner.
#   - mysqlmoodlepass: MySQL moodle_ci_site pass.
#   - mysqljenkinsuser: MySQL jenkins user (will execute all the jobs).
#   - mysqljenkinspass: MySQL jenkins pass.
#   - moodlewwwroot: $CFG->wwwroot of the Moodle site.
#   - moodleadminuser: Username of the Moodle site admin.
#   - moodleadminpass: Password of the Moodle site admin.

# Verify ALL the variables are defined
required="basedir gitdir datadir moodledir moodledatadir \
    gitcmd mysqlcmd phpcmd mysqladminuser mysqladminpass \
    mysqlmoodleuser mysqlmoodlepass mysqljenkinsuser mysqljenkinspass \
    moodlewwwroot moodleadminuser moodleadminpass"
for var in $required; do
    if [ -z ${!var} ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# Create all the required directories (gitdir, datadir, moodledir, moodledata)
if [ ! -d "${basedir}" ]; then
    echo "Error: basedir ${basedir} does not exist."
    exit 1
fi
if [ ! -w "${basedir}" ]; then
    echo "Error: basedir ${basedir} is not writable."
    exit 1
fi
if [ -d "${basedir}/${gitdir}" ]; then
    echo "Skip: gitdir ${basedir}/${gitdir} already exists."
else
    mkdir ${basedir}/${gitdir}
fi
if [ -d "${basedir}/${gitdir}/${moodledir}" ]; then
    echo "Skip: moodledir ${basedir}/${gitdir}/${moodledir} already exists."
else
    mkdir ${basedir}/${gitdir}/${moodledir}
fi
if [ -d "${basedir}/${datadir}" ]; then
    echo "Skip: datadir ${basedir}/${datadir} already exists."
else
    mkdir ${basedir}/${datadir}
fi
if [ -d "${basedir}/${datadir}/${moodledatadir}" ]; then
    echo "Skip: moodledatadir ${basedir}/${datadir}/${moodledatadir} already exists."
else
    mkdir ${basedir}/${datadir}/${moodledatadir}
fi

# Create the git clone for the moodle_ci_site, master branch v2.4.0-beta, yes harcoded.
if [ -d "${basedir}/${gitdir}/${moodledir}/.git" ]; then
    echo "Skip: git://git.moodle.org/moodle.git clone already present at ${basedir}/${gitdir}/${moodledir}"
else
    cd ${basedir}/${gitdir}/${moodledir} && ${gitcmd} clone git://git.moodle.org/moodle.git .
fi
cd ${basedir}/${gitdir}/${moodledir} && ${gitcmd} pull origin master && ${gitcmd} reset --hard v2.4.0-beta

# Create the git clone for the codechecker, master branch and add it to .git/info/exclude
if [ -d "${basedir}/${gitdir}/${moodledir}/local/codechecker" ]; then
    echo "Skip https://github.com/moodlehq/moodle-local_codechecker.git already present at local/codechecker"
else
    cd ${basedir}/${gitdir}/${moodledir}/local && ${gitcmd} clone git://github.com/moodlehq/moodle-local_codechecker.git codechecker
    echo local/codechecker >> ${basedir}/${gitdir}/${moodledir}/.git/info/exclude
fi
cd ${basedir}/${gitdir}/${moodledir}/local/codechecker && ${gitcmd} pull origin master && ${gitcmd} reset --hard origin/master

# Create the git clone for the moodlecheck, master branch and add it to .git/info/exclude
if [ -d "${basedir}/${gitdir}/${moodledir}/local/moodlecheck" ]; then
    echo "Skip https://github.com/moodlehq/moodle-local_moodlecheck.git already present at local/moodlecheck"
else
    cd ${basedir}/${gitdir}/${moodledir}/local && ${gitcmd} clone git://github.com/moodlehq/moodle-local_moodlecheck.git moodlecheck
    echo local/moodlecheck >> ${basedir}/${gitdir}/${moodledir}/.git/info/exclude
fi
cd ${basedir}/${gitdir}/${moodledir}/local/moodlecheck && ${gitcmd} pull origin master && ${gitcmd} reset --hard origin/master

# Create the git clone for the ci, master branch and add it to .git/info/exclude
if [ -d "${basedir}/${gitdir}/${moodledir}/local/ci" ]; then
    echo "Skip https://github.com/moodlehq/moodle-local_ci.git already present at local/ci"
else
    cd ${basedir}/${gitdir}/${moodledir}/local && ${gitcmd} clone git://github.com/moodlehq/moodle-local_ci.git ci
    echo local/ci >> ${basedir}/${gitdir}/${moodledir}/.git/info/exclude
fi
cd ${basedir}/${gitdir}/${moodledir}/local/ci && ${gitcmd} pull origin master && ${gitcmd} reset --hard origin/master

# Create the moodle_ci_database if doesn't exist, using the mysql admin credentials
dbexists=$( ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} \
    --batch --skip-column-names \
    --execute="SHOW DATABASES LIKE '${moodledir}'")
if [ -z "${dbexists}" ]; then
    ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} \
    --execute="CREATE DATABASE ${moodledir} CHARACTER SET utf8 COLLATE utf8_bin"
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error creating the DB ${moodledir}"
        exit $exitstatus
    fi
else
    echo "Skip creating the ${moodledir} database. Already exists"
fi

# Create the mysqlmoodleuser with all privileges on the moodle_ci_database, using the mysql admin credentials
userexists=$( ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} --database=mysql \
    --batch --skip-column-names \
    --execute="SELECT * FROM user WHERE user = '${mysqlmoodleuser}'")
if [ -z "${userexists}" ]; then
    ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} \
    --execute="GRANT ALL PRIVILEGES ON ${moodledir}.* TO '${mysqlmoodleuser}'@'localhost' IDENTIFIED BY '${mysqlmoodlepass}' WITH GRANT OPTION"
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error creating the user ${mysqlmoodleuser}"
        exit $exitstatus
    fi
else
    echo "Skip creating the ${mysqlmoodleuser} database user. Already exists"
fi

# Create the mysqljenkinsuser with all privileges on all the dbs, using the mysql admin credentials
userexists=$( ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} --database=mysql \
    --batch --skip-column-names \
    --execute="SELECT * FROM user WHERE user = '${mysqljenkinsuser}'")
if [ -z "${userexists}" ]; then
    ${mysqlcmd} --user=${mysqladminuser} --password=${mysqladminpass} \
    --execute="GRANT ALL PRIVILEGES ON *.* TO '${mysqljenkinsuser}'@'localhost' IDENTIFIED BY '${mysqljenkinspass}' WITH GRANT OPTION"
    exitstatus=${PIPESTATUS[0]}
    if [ $exitstatus -ne 0 ]; then
        echo "Error creating the user ${mysqljenkinsuser}"
        exit $exitstatus
    fi
else
    echo "Skip creating the ${mysqljenkinsuser} database user. Already exists"
fi

# Install the Moodle site once all the stuff above is available
cd ${basedir}/${gitdir}/${moodledir}
if [ ! -f "${basedir}/${gitdir}/${moodledir}/config.php" ]; then
    ${phpcmd} admin/cli/install.php --non-interactive --allow-unstable --agree-license \
        --wwwroot="${moodlewwwroot}" \
        --dataroot="${basedir}/${datadir}/${moodledatadir}" \
        --dbtype=mysqli --dbhost=localhost --dbname=${moodledir} \
        --dbuser=${mysqlmoodleuser} --dbpass=${mysqlmoodlepass} --prefix=mdl_ \
        --fullname="Moodle Integration Site" --shortname="MIS" \
        --adminuser=${moodleadminuser} --adminpass=${moodleadminpass}
else
    echo "Skip Moodle installation, "${basedir}/${gitdir}/${moodledir}/config.php" already exists"
fi
