#!/bin/bash
# $gitdir: Directory containing git repo
# $gitbranch: Branch we are going to examine

# calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# dirs and files (egrep-like regexp) we are going to exclude from analysis
. ${mydir}/../define_excluded/define_excluded.sh

# files where results will be sent
lastfile=$WORKSPACE/illegal_whitespace_last_execution_$gitbranch.txt
correctfile=$WORKSPACE/illegal_whitespace_last_correct_$gitbranch.txt
difffile=$WORKSPACE/illegal_whitespace_diff_$gitbranch.txt
countfile=$WORKSPACE/illegal_whitespace_counters_$gitbranch.csv
mincountfile=$WORKSPACE/illegal_whitespace_mincounter_$gitbranch.csv

# Co to proper gitdir and gitpath
cd $gitdir && git checkout $gitbranch && git reset --hard origin/$gitbranch

# Search and send to $lastfile
echo -n > "$lastfile"
for i in `find . -type f`
do
    if [[ $i =~ $excluded_grep ]]
    then
        continue
    fi
    content=`grep -PIn '^[ \t]+$|^ *\t *.+$|^.*[ \t]+$' $i`
    if [ ! -z "$content" ]
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
echo "$BUILD_NUMBER	$BUILD_ID	$count" >> "$countfile"

# Get best count ever or create it
bestcount=999999
if [[ ! -f "$mincountfile" ]]
then
    # Create the file (first run) with current counter
    echo "$BUILD_NUMBER	$BUILD_ID	$bestcount" > "$mincountfile"
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
        echo "$BUILD_NUMBER	$BUILD_ID	$count" > "$mincountfile"
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
