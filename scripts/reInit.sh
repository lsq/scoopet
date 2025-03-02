#!/usr/bin/env bash

gitSummary=$(git diff --compact-summary HEAD^ | sed -n '$!p')
repoPath=$(git rev-parse --show-toplevel)

while read line
do
    # echo "-$line"
    filep=$(awk '{print $1}' <<<"$line")
    if grep 'new' <<<"$line" ; then
        # echo "$filep"
        continue
    else
        if [[ "$filep" =~ ^bucket ]]; then
            [ -f "$repoPath/$filep" ] && echo "$repoPath/$filep"
             rm -rf "$repoPath/$filep"
        fi
    fi
done <<<"$gitSummary"
