#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

rickshaw_directory=${1}

if ! pushd ${rickshaw_directory}; then
    exit 1
fi

if [ -f rickshaw-run -a -d userenvs ]; then
    ls -l userenvs/*.json
    exit 0
else
    ls -l
    exit 1
fi
