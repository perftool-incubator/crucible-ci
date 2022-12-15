#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

repository_name=${1}

repository_name=$(echo "${repository_name}" | sed -e "s|perftool-incubator/||")

echo "repo-name=${repository_name}"
if [ -n "${GITHUB_OUTPUT}" ]; then
    echo "repo-name=${repository_name}" >> ${GITHUB_OUTPUT}
else
    echo "WARNING: \$GITHUB_OUTPUT not defined"
fi
