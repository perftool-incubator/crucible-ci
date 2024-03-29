#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

crucible_directory=${1}
workshop_directory=${2}

function error() {
    echo "ERROR: ${1}"
    exit 1
}

function usage() {
    echo "Usage: ${0} <crucible> <workshop>"
    echo
    echo "<crucible> is a directory where the crucible repository exists."
    echo "<workshop> is a directory where the workshop repoistory exists."
    echo
    echo "Both repositories are examined to determine if their changes require"
    echo "the building of a new controller image for testing"
    exit 1
}

if [ -z "${crucible_directory}" -o -z "${workshop_directory}" ]; then
    usage
else
    # handle <crucible>
    if [ ! -e "${crucible_directory}" ]; then
        error "The crucible directory '${crucible_directory}' does not exist"
    fi

    if ! pushd ${crucible_directory}; then
        error "Could not pushd to the crucible directory '${crucible_directory}'"
    else
        echo "Contents of crucible workshop directory:"
        if [ -f crucible-install.sh -a -d workshop -a -f workshop/build-controller.sh -a -f workshop/controller-workshop.json ]; then
            ls -l workshop/
        else
            ls -l
            error "Could not find the required crucible workshop directory contents"
        fi

        popd
    fi

    # handle <workshop>
    if [ ! -e "${workshop_directory}" ]; then
        error "The workshop directory '${workshop_directory}' does not exist"
    fi

    if ! pushd ${workshop_directory}; then
        error "Could not pushd to the workshop directory '${workshop_directory}'"
    else
        echo "Contents of the workshop directory:"
        ls -l
        if [ ! -f workshop.pl -o ! -f schema.json ]; then
            error "Could not find required workshop directory contents"
        fi

        popd
    fi

    exit 0
fi
