#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}

if pushd ${crucible_directory}; then
    diff_cmd="git diff --name-only HEAD^1 HEAD"

    echo "Files changed:"
    ${diff_cmd}
    echo

    workshop_files_changed=$(${diff_cmd} | grep "^workshop/" | wc -l)
    echo "workshop_files_changed=${workshop_files_changed}"
    echo

    if [ ${workshop_files_changed} -gt 0 ]; then
	build_controller="yes"
    else
	build_controller="no"
    fi

    echo "Setting build-controller to '${build_controller}'"
    echo "::set-output name=build-controller::${build_controller}"
else
    exit 1
fi
