#!/bin/bash

# Fail immediately
set -e

# Config
no_of_args=2

# CLI parameters
writefile="$1"
writestr="$2"

# Error handling for parameters
if [ $# -ne 2 ]; then
    printf "ERROR: Number of arguments passed is %s, but %s expected.\n" "$#" "${no_of_args}"
    printf "Usage: %s <writefile> <writestr>\n\n" "$0"
    printf "Example invocation:\n"
    printf "\t%s /tmp/aesd/assignment1/sample.txt ios\n\n" "$0"
    exit 1
fi
if [ -z "${writestr}" ]; then
    printf "ERROR: Provided search string is empty! Exiting!\n\n"
    exit 1
fi

# Create dir
_dir_path=$(dirname "${writefile}")
if [ ! -d "${_dir_path}" ]; then
    if ! mkdir -p "${_dir_path}"; then
        printf "ERROR: Wasn't able to create directory at provided file path '%s'! Exiting!\n\n" "${_dir_path}"
        exit 1
    fi
fi

# Create file
if ! echo "${writestr}" > "${writefile}"; then
    printf "ERROR: Wasn't able to create file at provided file path '%s'! Exiting!\n\n" "${writefile}"
    exit 1
fi
