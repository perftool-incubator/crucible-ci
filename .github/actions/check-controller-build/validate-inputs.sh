#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}

if ! pushd ${crucible_directory}; then
    exit 1
fi

if [ -f crucible-install.sh -a -d workshop -a -f workshop/build-controller.sh -a -f workshop/controller-workshop.json ]; then
    ls -l workshop/
    exit 0
else
    ls -l
    exit 1
fi
