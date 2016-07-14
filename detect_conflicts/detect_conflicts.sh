#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to examine

set -e

required="WORKSPACE gitdir gitbranch"
for var in ${required}; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# dirs and files (egrep-like regexp) we are going to exclude from analysis
exclude="/.git"

# files where results will be sent
lastfile=$WORKSPACE/detect_conflicts_last_execution_$gitbranch.txt
correctfile=$WORKSPACE/detect_conflicts_last_correct_$gitbranch.txt
difffile=$WORKSPACE/detect_conflicts_diff_$gitbranch.txt
countfile=$WORKSPACE/detect_conflicts_counters_$gitbranch.csv
mincountfile=$WORKSPACE/detect_conflicts_mincounter_$gitbranch.csv

# Co to proper gitdir and gitpath
cd $gitdir && git reset --hard $gitbranch

# Search and send to $lastfile
echo -n > "$lastfile"
find . -type f | while read i
do
    if [[ $i =~ $exclude ]]
    then
        continue
    fi
    # note cannot look for ={7} because it matches legit txt/markdown titles.
    if content=`grep -PIn '^(<{7}|\|{7}|>{7}) ' "$i"`
    then
        echo "## $i ##" >> "$lastfile"
        echo "$content" >> "$lastfile"
    fi
done

# Get the count from the previous execution
prevcount=999999
if [[ -f "$countfile" ]]
then
    prevcount=`tail -1 "$countfile" | cut -s -f3`
fi

# Count and send to countfile
count=`cat "$lastfile" | wc -l`
echo "$BUILD_NUMBER	$BUILD_TIMESTAMP	$count" >> "$countfile"

# Get best count ever or create it
bestcount=999999
if [[ ! -f "$mincountfile" ]]
then
    # Create the file (first run) with current counter
    echo "$BUILD_NUMBER	$BUILD_TIMESTAMP	$bestcount" > "$mincountfile"
else
    # Read the best counter
    bestcount=`tail -1 "$mincountfile" | cut -s -f3`
fi

echo " current count: $count"
echo "previous count: $prevcount"
echo "    best count: $bestcount"

# Exit status = 1 by default
status=1

# Compare counter with previous counter
if (($count > $prevcount))
then
    # The counter has grown, worse results: make difffile
    echo "worse results than previous counter"
    diff "$correctfile" "$lastfile" > "$difffile"
else
    # The counter is same or better, lets compare with best counter
    echo "same/better results than previous counter"
    if (($count < $bestcount))
    then
        # Best ever, save current counter as best, grab correctfile and delete diff
        echo "got best results ever, yay!"
        echo "$BUILD_NUMBER	$BUILD_TIMESTAMP	$count" > "$mincountfile"
        cp "$lastfile" "$correctfile"
        rm -fr "$difffile"
        status=0
    elif (($count == $bestcount))
    then
        # Continue in best ever
        echo "continue in best results ever"
        rm -fr "$difffile"
        status=0
    else
        # No best ever yet: make diff file
        echo "still no back to best ever"
        diff "$correctfile" "$lastfile" > "$difffile"
    fi
fi
exit $status
