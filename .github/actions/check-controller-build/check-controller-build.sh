#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}

if pushd ${crucible_directory}; then
    build_controller="no"

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
    if git log HEAD^1 > /dev/null 2>&1; then
        # history available

        diff_cmd="git diff --name-only HEAD^1 HEAD"

        echo "Files changed:"
        ${diff_cmd}
        if [ $? != 0 ]; then
            echo "ERROR: could not obtain git-diff output"
            exit 1
        fi
        echo

        workshop_files_changed=$(${diff_cmd} | grep "^workshop/" | wc -l)
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

    echo "Setting build-controller to '${build_controller}'"
    if [ -n "${GITHUB_OUTPUT}" ]; then
        echo "build-controller=${build_controller}" >> ${GITHUB_OUTPUT}
    else
        echo "ERROR: \$GITHUB_OUTPUT not defined"
        exit 1
    fi
else
    echo "ERROR: Failed to pushd to ${crucible_directory}"
    exit 1
fi

exit 0
