#!/bin/sh

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

no_of_files=$(find "$filesdir" -type f | wc -l || true)

# Reminder:
# - grep in busybox binary doesn't support long name parameters!
# - /bin/sh doesn't suuport arrays!
#
# Using awk to create the sum, as suggested by GitHub Copilot
no_of_matches=$(
    find "${filesdir}" -type f -exec grep -c -H "${searchstr}" {} \; |
    awk -F: '{sum += $2} END {print sum}' || true
)

printf "The number of files are %d and the number of matching lines are %d\n\n" "${no_of_files}" "${no_of_matches}"
