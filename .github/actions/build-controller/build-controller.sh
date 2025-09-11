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
            weekly_ci_auth_file="/root/crucible-weekly-ci-engines-token.json"
            ci_auth_file="/root/crucible-ci-engines-token.json"
            AUTH_TOKEN_FILE_FOUND=0
            AUTH_FILE=""
            engine_auth_tokens_found=0
            if [ -e "${weekly_ci_auth_file}" -a -s "${weekly_ci_auth_file}" ]; then
                echo "Found weekly ci engine registry auth token file: ${weekly_ci_auth_file}" 
                (( engine_auth_tokens_found += 1 ))

                AUTH_FILE=${weekly_ci_auth_file}
                AUTH_TOKEN_FILE_FOUND=1
                AUTH_TOKEN_TYPE="WEEKLY-CI"
            fi
            if [ -e "${ci_auth_file}" -a -s "${ci_auth_file}" ]; then
                echo "Found ci engine registry auth token file: ${ci_auth_file}"
                (( engine_auth_tokens_found += 1 ))

                AUTH_FILE=${ci_auth_file}
                AUTH_TOKEN_FILE_FOUND=1
                AUTH_TOKEN_TYPE="CI"
            fi
            if [ ${engine_auth_tokens_found} -ne 1 ]; then
                echo "ERROR: It does not make sense for anything other than one engine registry auth token file to exist (found ${engine_auth_tokens_found})"
                exit 1
            elif [ ${AUTH_TOKEN_FILE_FOUND} -eq 1 ]; then
                echo "Engine Registry Auth Token Summary:"
                echo "  File: ${AUTH_FILE}"
                echo "  Type: ${AUTH_TOKEN_TYPE}"
            fi

            run_cmd "podman image push --authfile ${AUTH_FILE} ${controller_image} quay.io/crucible/crucible-ci-controller:${CI_PUSH_TAG}"
        fi
    else
        echo "ERROR: Failed to isolate new Crucible controller image"
        RC_STATUS=1
    fi

    stop_github_group
fi

echo "exiting with RC_STATUS=${RC_STATUS}"
exit ${RC_STATUS}
