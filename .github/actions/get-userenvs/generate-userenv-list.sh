#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

rickshaw_directory=${1}
excludes="stream8-flexran"

if pushd ${rickshaw_directory}; then
    userenvs=$(find userenvs/ -maxdepth 1 -name '*.json' | sed -e 's|userenvs/||' -e 's|\.json||')
    # Discard excluded envs
    for ex in ${excludes[@]}; do
        new=( "${userenvs[@]/$ex}" )
        userenvs=$new
    done
    userenvs_json="[\"default\","
    for userenv in ${userenvs}; do
        userenvs_json+="\"${userenv}\","
    done
    userenvs_json=$(echo "${userenvs_json}" | sed -e "s/,$//")
    userenvs_json+="]"
    echo "userenvs_json=${userenvs_json}"
    if [ -n "${GITHUB_OUTPUT}" ]; then
        echo "userenvs=${userenvs_json}" >> ${GITHUB_OUTPUT}
    else
        echo "WARNING: \$GITHUB_OUTPUT not defined"
    fi
    exit 0
else
    exit 1
fi
