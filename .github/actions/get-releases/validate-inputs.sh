#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}
build_controller=${2}

if ! pushd ${crucible_directory}; then
    exit 1
fi

ls -l
if [ ! -f crucible-install.sh ]; then
    exit 1
fi

case "${build_controller}" in
    "yes"|"no")
        echo "valid build-controller: ${build_controller}"
        ;;
    *)
        echo "invalid build-controller: ${build_controller}"
        exit 1
        ;;
esac

exit 0
