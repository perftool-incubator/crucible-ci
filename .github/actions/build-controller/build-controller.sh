#!/usr/bin/env bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_DIR=$(readlink -e ${SCRIPT_DIR})

source ${SCRIPT_DIR}/base

CI_VERBOSE=0

CI_RUN_ENVIRONMENT="standalone"

CI_PUSH_TAG="latest"

longopts="verbose,run-environment:,push-tag:"
opts=$(getopt -q -o "" --longoptions "${longopts}" -n "$0" -- "$@")
if [ ${?} -ne 0 ]; then
    echo "ERROR: Unrecognized option specified: $@"
    exit 1
fi
eval set -- "${opts}"
while true; do
    case "${1}" in
        --push-tag)
            shift
            CI_PUSH_TAG="${1}"
            shift
            ;;
        --run-environment)
            shift
            CI_RUN_ENVIRONMENT="${1}"
            shift
            ;;
        --verbose)
            shift
            CI_VERBOSE=1
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "ERROR: Unexpected argument [${1}]"
            shift
            break
            ;;
    esac
done

run_cmd "crucible wrapper /opt/crucible/workshop/build-controller.sh --config /opt/crucible/subprojects/core/crucible-ci/actions/build-controller/files/ci-config.json"

run_and_capture_cmd "podman images"
podman_images="${captured_output}"

if [ ${RC_STATUS} == 0 -a -n "${podman_images}" ]; then
    header="Identifying New Crucible Controller Image"
    start_github_group "${header}"
    echo "${header}"
    echo

    controller_image_line=$(echo "${podman_images}" | grep crucible-controller)

    if [ -n "${controller_image_line}" ]; then
        controller_image=$(echo "${controller_image_line}" | awk '{ print $1":"$2 }')
        echo "New controller image name: ${controller_image}"

        run_cmd "podman image inspect ${controller_image}"

        if [ ${RC_STATUS} == 0 ]; then
            auth_file="/root/crucible-ci-engines-token.json"
            if [ -e "${auth_file}" ]; then
                run_cmd "podman image push --authfile ${auth_file} ${controller_image} quay.io/crucible/crucible-ci-controller:${CI_PUSH_TAG}"
            else
                echo "ERROR: Could not find authorization file ${auth_file}"
                RC_STATUS=1
            fi
        fi
    else
        echo "ERROR: Failed to isolate new Crucible controller image"
        RC_STATUS=1
    fi

    stop_github_group
fi

echo "exiting with RC_STATUS=${RC_STATUS}"
exit ${RC_STATUS}
