#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}
workshop_directory=${2}

function error() {
    echo "ERROR: ${1}"
    exit 1
}

# validate that the proper history is available to determine if
# the controller needs to be built (the github checkout action
# requires special arguments -- fetch-depth -- to be able to do
# this, otherwise history is not available) (the checkout action
# does not include history by default as an optimization since it
# is usually not necessary)
#
# assume that if the proper history is not available that is
# because the code being examined is not from a submitted PR but
# the committed upstream repository -- meaning no controller build
# required
available_history="git log --oneline origin/master...HEAD"
diff_cmd="git diff --name-only origin/master...HEAD"

build_controller="no"

echo "Crucible workshop change analysis:"
if pushd ${crucible_directory}; then
    available_commits=$(${available_history} | wc -l)
    echo "Available commits: ${available_commits}"
    
    if [ ${available_commits} -gt 1 ]; then
        # history available

        echo "Available commits:"
        ${available_history}
        echo

        echo "Files changed:"
        ${diff_cmd}
        if [ $? != 0 ]; then
            error "could not obtain git-diff output"
        fi
        echo

        workshop_files_changed=$(${diff_cmd} | grep "^workshop/" | grep -v ".md$" | wc -l)
        echo "workshop_files_changed=${workshop_files_changed}"
        echo

        if [ ${workshop_files_changed} -gt 0 ]; then
            echo "INFO: controller build is required"
	    build_controller="yes"
        fi
    else
        # history not available

        echo "WARNING: Required history not available, assuming no controller build is required"
    fi

    popd
else
    error "Failed to pushd to crucible directory '${crucible_directory}'"
fi

echo "Workshop change analysis:"
if pushd ${workshop_directory}; then
    available_commits=$(${available_history} | wc -l)
    echo "Available commits: ${available_commits}"
    
    if [ ${available_commits} -gt 1 ]; then
        # history available

        echo "Available commits:"
        ${available_history}
        echo

        echo "Files changed:"
        ${diff_cmd}
        if [ $? != 0 ]; then
            error "could not obtian git-diff output"
        fi
        echo

        workshop_files_changed=$(${diff_cmd} | grep "^workshop.pl\|^schema.json" | wc -l)
        echo "workshop_files_changed=${workshop_files_changed}"
        echo

        if [ ${workshop_files_changed} -gt 0 ]; then
            echo "INFO: controller build is required"
            build_controller="yes"
        fi
    else
        # history not available

        echo "WARNING: Required history not available, assuming no controller build is required"
    fi

    popd
else
    error "Failed to pushd to workshop directory '${workshop_directory}'"
fi

echo "Setting build-controller to '${build_controller}'"
if [ -n "${GITHUB_OUTPUT}" ]; then
    echo "build-controller=${build_controller}" >> ${GITHUB_OUTPUT}
else
    error "\$GITHUB_OUTPUT not defined"
fi
exit 0
