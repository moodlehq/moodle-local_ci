#!/bin/bash
# $phpcmd: Path to the PHP CLI executable
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to check

# Let's go strict (exit on error)
set -e

# file where results will be sent
resultfile=$WORKSPACE/check_upgrade_savepoints_${gitbranch}.txt
echo -n > "$resultfile"

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# checkout pristine copy of the configure branch
cd $gitdir && git checkout $gitbranch && git reset --hard origin/$gitbranch

# copy the checker to the gitdir
cp $mydir/check_upgrade_savepoints.php $gitdir/

# Run the savpoints checker utility, saving results to file
${phpcmd} $gitdir/check_upgrade_savepoints.php > "$resultfile"

# remove the checker from gitdir
rm -fr $gitdir/check_upgrade_savepoints.php

# Look for ERROR or WARN in the resultsfile
count=`grep -P "ERROR|WARN" "$resultfile" | wc -l`
# Check if there are problems
if (($count > 0))
then
    exit 1
fi
exit 0
