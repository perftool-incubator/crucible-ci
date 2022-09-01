#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

rickshaw_directory=${1}

if pushd ${rickshaw_directory}; then
    userenvs=$(find userenvs/ -maxdepth 1 -name '*.json' | sed -e 's|userenvs/||' -e 's|\.json||')
    userenvs_json="[\"default\","
    for userenv in ${userenvs}; do
        userenvs_json+="\"${userenv}\","
    done
    userenvs_json=$(echo "${userenvs_json}" | sed -e "s/,$//")
    userenvs_json+="]"
    echo "userenvs_json=${userenvs_json}"
    echo
    echo "::set-output name=userenvs::${userenvs_json}"
    exit 0
else
    exit 1
fi
