#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}
build_controller=${2}

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
diff_cmd_validate="git log HEAD^1"
diff_cmd="git diff --name-only HEAD^1 HEAD"

INSTALLER_PATH="${crucible_directory}/crucible-install.sh"

installer_changed="no"

echo "Crucible change analysis:"
if pushd ${crucible_directory}; then
    if ${diff_cmd_validate} > /dev/null 2>&1; then
        # history available

        echo "Files changed:"
        ${diff_cmd}
        if [ $? != 0 ]; then
            echo "ERROR: Could not obtain git-diff output"
            exit 1
        fi
        echo

        installer_changes=$(${diff_cmd} | grep "^crucible-install.sh" | wc -l)
        echo "installer_changes=${installer_changes}"
        echo

        if [ ${installer_changes} -gt 0 ]; then
            echo "INFO: the installer has changed"
            installer_changed="yes"
        fi
    else
        # history is not available

        echo "INFO: Required history not availble, assuming no changes to installer script"
    fi

    popd
else
    echo "ERROR: Could not pushd to Crucible directory: ${crucible_directory}"
    exit 1
fi

releases_json="["
releases_json+="\"upstream\","

echo "build_controller=${build_controller}"
echo "installer_changed=${installer_changed}"
if [ "${build_controller}" == "yes" -o "${installer_changed}" == "yes" ]; then
    releases=$(${INSTALLER_PATH} --list-releases)
    for release in ${releases}; do
        releases_json+="\"${release}\","
    done
fi

releases_json=$(echo "${releases_json}" | sed -e "s/,$//")
releases_json+="]"

echo "releases_json=${releases_json}"
if [ -n "${GITHUB_OUTPUT}" ]; then
    echo "releases=${releases_json}" >> ${GITHUB_OUTPUT}
else
    echo "WARNING: \$GITHUB_OUTPUT not defined"
fi

exit 0
