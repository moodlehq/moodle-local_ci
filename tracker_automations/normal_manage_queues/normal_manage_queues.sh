#!/usr/bin/env bash
# This script adds some automatisms helping to manage the integration queues:
#  - candidates queue: issues awaiting from integration not yet in current.
#  - current queue: issues under current integration.
#
# The automatisms are as follow:
#  A) Move (if not blocked) "important" issues from candidates to current.
#  B) Keep the current queue fed with (not blocked) issues from the candidates queue in rigorous priority order.
#    - When the number of issues awaiting for integration falls below a threshold (currentmin).
#    - Moving up to a maximum number of issue (movemax).
#  C) Raise the integration priority of all the issues sitting in the candidates queue too long,
#     in order to guarantee that they will be moved to current integration sooner. But avoid
#     modifying the priority of any issue being blocked or blocking to others. This type of issues
#     are managed exclusively by the set_integration_priority_to_[zero|one] scripts.
# Note that all the "move to current" operations are always subject to the issue being free of unresolved blockers.

# The criteria to consider an issue "important" are:
#  1) It must be in the candidates queue, awaiting for integration.       |
#  2) It must not have the integration_held or security_held labels.      | => filter=14000
#  3) It must not have the "agreed_to_be_after_release" text in a comment.| => NOT filter = 21366
#  4) At least one of this is true:
#    a) The issue has a must-fix version.                                 | => filter = 21363
#    b) The issue has the mdlqa label.                                    | => labels IN (mdlqa)
#    c) The issue priority is critical or higher.                         | => priority IN (Critical, Blocker)
#    d) The issue is flagged as security issue.                           | => level IS NOT EMPTY
#    e) The issue belongs to some of these components:                    | => component IN (...)
#      - Privacy
#      - Automated functional tests (behat)
#      - Unit tests
#
# This job must be enabled over normal weeklies period (since end of on-sync to freeze).
# (see https://moodledev.io/general/development/process/release#2-weeks-after)
#
# Parameters:
#  jiraclicmd: fill execution path of the jira cli
#  jiraserver: jira server url we are going to connect to
#  jirauser: user that will perform the execution
#  jirapass: password of the user
#  currentmin: optional (dflt. 15), number of issue under which the current queue will be fed from the candidates one.
#  movemax: optional (dflt. 3), max number of issue that will be moved from candidates to current when under currentmin.
#  waitingdays: optional (dflt. 14), number of days an issue sits as candidate before its integraton priority is raised.
#  dryrun: don't perfomr any write operation, only reads. Defaults to empty (false).

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE"
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
resultfile=$WORKSPACE/normal_manage_queues.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/normal_manage_queues.log

# Calculate some variables
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

source ${mydir}/lib.sh # Add all the functions.

# Set defaults
currentmin=${currentmin:-15}
movemax=${movemax:-3}
waitingdays=${waitingdays:-14}
dryrun=${dryrun:-}

if [ -n "${dryrun}" ]; then
    echo "Dry-run enabled, no changes will be performed to the tracker"
fi

# A, move "important" issues from candidates to current.
# Note: This has been disabled as of 2023-07-13. See MDLSITE-7296 for more information.
echo "Automatism A disabled, not considering important issues any more"
# run_A

# B, keep the current queue fed with issues when it's under a threshold.
run_B

# C, raise interation priority for issues awaiting as candidates too long.
# Note: This has been disabled as of 2023-07-13. See MDLSITE-7296 for more information.
echo "Automatism C disabled, not raising the integration priority of issues waiting too long any more"
# run_C

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"
