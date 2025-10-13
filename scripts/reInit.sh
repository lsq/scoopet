#!/usr/bin/env bash

gitSummary=$(git diff --compact-summary ivaquero/master master | sed -n '$!p')
repoPath=$(git rev-parse --show-toplevel)
tmdir=$(mktemp -d)

cp .github/CODEOWNERS "$tmdir/"

while read line
do
    # echo "-$line"
    filep=$(awk '{print $1}' <<<"$line")
    if grep 'new' <<<"$line" ; then
        # echo "$filep"
        #cp --parent "$repoPath/$filep" "$tmdir/"
        tar -cf - "./$filep" | tar -xf - -C "$tmdir/"
        continue
    else
        if [[ "$filep" =~ ^bucket ]]; then
            [ -f "$repoPath/$filep" ] && echo "$repoPath/$filep"
            rm -rf "$repoPath/$filep"
        fi
    fi
done <<<"$gitSummary"
