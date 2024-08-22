#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

bypass_controller_build=${1}
force_controller_build=${2}
crucible_directory=${3}
workshop_directory=${4}

function error() {
    echo "ERROR: ${1}"
    exit 1
}

function usage() {
    echo "Usage: ${0} <bypass-controller-build> <force-controller-build> <crucible> <workshop>"
    echo
    echo "<bypass-controller-build> is a yes|no value"
    echo "<force-controller-build> is a yes|no value"
    echo "<crucible> is a directory where the crucible repository exists."
    echo "<workshop> is a directory where the workshop repoistory exists."
    echo
    echo "If <bypass-controller-build> is 'yes' then the action short circuits and returns 'no'"
    echo
    echo "If <force-controller-build> is 'yes' then the action short circuits and returns 'yes'"
    echo
    echo "If <bypass-controller-build> and <force-controller-build> are both set to 'yes' then"
    echo "an error is emitted since the two parameters are mutually exclusive"
    echo
    echo "Both repositories are examined to determine if their changes require"
    echo "the building of a new controller image for testing"
    exit 1
}

if [ -z "${bypass_controller_build}" -o -z "${force_controller_build}" -o -z "${crucible_directory}" -o -z "${workshop_directory}" ]; then
    usage
else
    # handle <bypass-controller-build>
    case "${bypass_controller_build}" in
        "yes"|"no")
            echo "bypass_controller_build has a valid value of '${bypass_controller_build}'"
            ;;
        *)
            error "bypass_controller_build has an invalid value of '${bypass_controller_build}'"
            ;;
    esac

    # handle <force-controller-build>
    case "${force_controller_build}" in
        "yes"|"no")
            echo "force_controller_build has a valid value of '${force_controller_build}'"
            ;;
        *)
            error "force_controller_build has an invalid value of '${force_controller_build}'"
            ;;
    esac

    # handle mutual exclusions
    if [ "${bypass_controller_build}" == "yes" -a "${force_controller_build}" == "yes" ]; then
        error "You cannot set bypass_controller_build and force_controller_build to 'yes' at the same time"
    fi
    
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
