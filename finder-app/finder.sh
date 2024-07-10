#!/bin/bash

# Fail immediately
set -e

# Config
no_of_args=2
no_of_files=0
no_of_matches=0

# CLI parameters
filesdir="$1"
searchstr="$2"

# Error handling for parameters
if [ $# -ne 2 ]; then
    printf "ERROR: Number of arguments passed is %s, but %s expected.\n" "$#" "${no_of_args}"
    printf "Usage: %s <filesdir> <searchstr>\n\n" "$0"
    printf "Example invocation:\n"
    printf "\t%s /tmp/aesd/assignment1 linux\n\n" "$0"
    exit 1
fi
if [ ! -d "${filesdir}" ]; then
    printf "ERROR: Provided files dir '%s' doesn't exist! Exiting!\n\n" "${filesdir}"
    exit 1
fi
if [ -z "${searchstr}" ]; then
    printf "ERROR: Provided search string is empty! Exiting!\n\n"
    exit 1
fi

# Determine number of files in filesdir
# (Using array as suggested by GitHub Copilot)
readarray -t files_in_dir <<< "$(find "$filesdir" -type f || true)"
no_of_files="${#files_in_dir[@]}"

# Determine number of files containing searchstr
# (Using awk instead of a for loop as suggested by GitHub Copilot)
no_of_matches=$(
    grep --count "$searchstr" "${files_in_dir[@]}" |
    awk -F: '{sum += $2} END {print sum}' || true
)

printf "The number of files are %s and the number of matching lines are %s\n\n" "${no_of_files}" "${no_of_matches}"
