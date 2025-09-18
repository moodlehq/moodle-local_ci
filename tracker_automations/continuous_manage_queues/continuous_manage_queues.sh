#!/usr/bin/env bash
# This script adds some automatisms helping to manage the integration queues:
#  - candidates queue: issues awaiting from integration not yet in current.
#  - current queue: issues under current integration.
#
# The automatisms are as follow:
#  A) Before release only! (normally 5 weeks of continuous between freeze and release)
#    1) Add the "integration_held" (+ standard comment) to new features & improvements issue missing it @ candidates (IR & CLR).
#    2) Move (if not blocked) "important" issues from candidates to current.
#    3) Move (if not blocked) issues away from the candidates queue.
#      a) Before a date (last week), keep the current queue fed with bug issues when it's under a threshold.
#      b) After a date (last week), add the "integration_held" (+ standard comment) to bug issues (IR & CLR).
#  B) After release only! (normally 2 weeks of on-sync continuous after release)
#    1) Move (if not blocked) issues away from the candidates queue.
#      a) Add the "integration_held" (+ on-sync standard comment) to new features and improv. missing it @ candidates (IR & CLR).
#      b) Keep the current queue fed with bug issues when it's under a threshold.
#  C) Move, always, all held issues awaiting for integration away from current integration.
#
# Note that all the "move to current" operations are always subject to the issue being free of unresolved blockers.
#
# The criteria to consider an issue "important" are:
#  1) It must be in the candidates queue, awaiting for integration.        |
#  2) It must not have the integration_held or security_held labels.      | => filter=14000
#  3) It must not have the "agreed_to_be_after_release" text in a comment.| => NOT filter = 21366
#  4) At least one of this is true:
#    a) The issue has a must-fix version.                                 | => filter = 21363
#    b) The issue has the mdlqa label.                                    | => labels IN (mdlqa)
#
# This job must be enabled only since freeze day to the end of on-sync period, when normal weeklies begin.
# (see https://moodledev.io/general/development/process/release#5-weeks-prior)
#
# Parameters:
#  jiraclicmd: fill execution path of the jira cli
#  jiraserver: jira server url we are going to connect to
#  jirauser: user that will perform the execution
#  jirapass: password of the user
#  releasedate: Release date, used to decide between A (before release) and B (after release) behaviors. YYYY-MM-DD.
#  lastweekdate: Last week date to decide between 2a - feed current and 2b - held bug issues. (YYY-MM-DD, defaults to release -1w)
#  currentmin: optional, number of issue under which the current queue will be fed from the candidates one.
#  movemax: optional, max number of issue that will be moved from candidates to current when under currentmin.
#  dryrun: don't perfomr any write operation, only reads. Defaults to empty (false).

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE releasedate"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load Jira Configuration.
source "${mydir}/../../jira.sh"

# file where results will be sent
resultfile=$WORKSPACE/continuous_manage_queues.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/continuous_manage_queues.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

source ${mydir}/lib.sh # Add all the functions.

# Set defaults
currentmin=${currentmin:-6}
movemax=${movemax:-3}
lastweekdate=${lastweekdate:-$(date -d "${releasedate} -7day" +%Y-%m-%d)}
dryrun=${dryrun:-}

# Today
nowdate=$(date +%Y%m%d)

run_param_validation $releasedate $lastweekdate

# Decide if we are going to proceed with behaviour A (before release) or behaviour B (after release)
behaviorAB=
if [ $nowdate -lt $(date -d "${releasedate}" +%Y%m%d) ]; then
    behaviorAB="before"
else
    behaviorAB="after"
fi

# Decide if we are going to proceed with behaviour A3a (before last week, keep current queue fed)
# or behaviour A3b (last-week, add the integration_held + standard last week message to any issue).
behaviorA3=
if [ $behaviorAB == "before" ]; then # Only calculate this before release.
    if [ $nowdate -lt $(date -d "${lastweekdate}" +%Y%m%d) ]; then
        behaviorA3="move"
    else
        behaviorA3="hold"
    fi
fi

if [ -n "${dryrun}" ]; then
    echo "Dry-run enabled, no changes will be performed to the tracker"
fi

# Behaviour A, before the release (normally the 5 weeks between freeze and release).
echo "Current time period is ${behaviorAB} the release, lastweekdate is ${lastweekdate}"
echo "Current behaviour is ${behaviourA3}"

if [ $behaviorAB == "before" ]; then
    # A1, add the "integration_held" + standard comment to any new feature or improvement arriving to candidates.
    echo "Holding new features and improvements arriving to candidates queue"
    run_A1

    # A2, move "important" issues from candidates to current
    # Note: This has been disabled as of 2023-07-13. See MDLSITE-7296 for more information.
    # Note: This has been (partially) enabled again as of 2023-08-29. See MDLSITE-7296 for more information.
    echo "Moving important issues from the candidates queue to current queue"
    run_A2

    # A3, move all issues aways from candidates queue:
    if [ $behaviorA3 == "move" ]; then
        # A3a, keep the current queue fed with bug issues when it's under a threshold.
        echo "Keeping the current queue fed with bugs under threshold"
        run_A3a
    fi
    if [ $behaviorA3 == "hold" ]; then
        # A3b, add the "integration_held" + standard comment to any issue arriving to candidates.
        echo "Holding all issues arriving to candidates queue"
        run_A3b
    fi
fi

# Behaviour B, after the release (normally the 2 weeks of on-sync).

if [ $behaviorAB == "after" ]; then
    # B1b, add the "integration_held" + standard on-sync comment to any new feature or improvement arriving to candidates.
    echo "Holding new features and improvements arriving to candidates queue"
    run_B1a

    # B1a, keep the current queue fed with bug issues when it's under a threshold.
    echo "Keeping the current queue fed with bugs under threshold"
    run_B1b
fi

# Task C, move, always, all held issues awaiting for integration away from current integration.
echo "Moving all held issues away from current integration"
run_C

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"
