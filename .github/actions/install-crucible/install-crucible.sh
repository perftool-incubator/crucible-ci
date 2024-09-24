#!/usr/bin/env bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_DIR=$(readlink -e ${SCRIPT_DIR})

source ${SCRIPT_DIR}/base

CRUCIBLE_INSTALL_SRC="https://raw.githubusercontent.com/perftool-incubator/crucible/master/crucible-install.sh"
CI_TARGET="none"
CI_TARGET_DIR="none"
CI_RUN_ENVIRONMENT="standalone"
CI_ENDPOINT="remotehost"
CI_CONTROLLER_TAG="none"
CI_CONTROLLER="no"

REGISTRY_TLS_VERIFY="true"

longopts="run-environment:,ci-target:,ci-target-dir:,ci-endpoint:,controller-tag:,ci-controller:"
opts=$(getopt -q -o "" --longoptions "${longopts}" -n "$0" -- "$@")
if [ ${?} -ne 0 ]; then
    echo "ERROR: Unrecognized option specified: $@"
    exit 1
fi
eval set -- "${opts}"
while true; do
    case "${1}" in
        --ci-controller)
            shift
            CI_CONTROLLER="${1}"
            shift
            ;;
        --controller-tag)
            shift
            CI_CONTROLLER_TAG="${1}"
            shift
            ;;
        --run-environment)
            shift
            CI_RUN_ENVIRONMENT="${1}"
            shift
            ;;
        --ci-target)
            shift
            CI_TARGET="${1}"
            shift
            ;;
        --ci-target-dir)
            shift
            CI_TARGET_DIR="${1}"
            shift
            ;;
        --ci-endpoint)
            shift
            CI_ENDPOINT="${1}"
            shift
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

# validate inputs
validate_ci_run_environment
validate_ci_endpoint

ci_auth_file="/root/crucible-ci-engines-token.json"
production_auth_file="/root/crucible-production-engines-token.json"
if [ -e "${ci_auth_file}" -a -s "${ci_auth_file}" -a -e "${production_auth_file}" -a -s "${production_auth_file}" ]; then
    echo "ERROR: It does not make sense for both the ci (${ci_auth_file}) and production (${production_auth_file}) client-server registry auth token files to exist"
    exit 1
fi

AUTH_TOKEN_FILE_FOUND=0
if [ -e "${ci_auth_file}" -a -s "${ci_auth_file}" ]; then
    echo "Found ci client-server registry auth token file: ${ci_auth_file}"
    auth_file=${ci_auth_file}
    AUTH_TOKEN_FILE_FOUND=1
    AUTH_TOKEN_TYPE="CI"
else
    echo "No ci client-server registry auth token file found: ${ci_auth_file}"

    if [ -e "${production_auth_file}" -a -s "${production_auth_file}" ]; then
        echo "Found production client-server registry auth token file: ${production_auth_file}"
        auth_file=${production_auth_file}
        AUTH_TOKEN_FILE_FOUND=1
        AUTH_TOKEN_TYPE="PRODUCTION"
    else
        echo "No production client-server registry auth token file found: ${production_auth_file}"
    fi
fi

# ensure endpoint availability
case "${CI_ENDPOINT}" in
    k8s)
        if [ ${AUTH_TOKEN_FILE_FOUND} == 0 ]; then
            start_github_group "Configuring Crucible for local k8s registry"
            CONTAINER_REGISTRY="localhost:32000/engines"
            REGISTRY_TLS_VERIFY="false"
            stop_github_group
        fi
        ;;
    remotehost)
        if [ ${AUTH_TOKEN_FILE_FOUND} == 0 ]; then
            start_github_group "Configuring Crucible for local remotehost registry"
            CONTAINER_REGISTRY="dir:/home/crucible-containers/engines"
            stop_github_group
        fi
        ;;
esac

# condition environment for crucible
start_github_group "Create /etc/sysconfig"
mkdir -pv /etc/sysconfig
stop_github_group

start_github_group "Install Crucible"
if pushd ~/ > /dev/null; then
    INSTALLER_PATH="./crucible-install.sh"
    INSTALLER_ARGS=""
    if [ -n "${CI_TARGET}" -a -n "${CI_TARGET_DIR}" -a "${CI_TARGET}" == "crucible" ]; then
        INSTALLER_PATH="${CI_TARGET_DIR}/crucible-install.sh"
        INSTALLER_ARGS+=" --git-repo ${CI_TARGET_DIR}/.git"
    else
        wget -O ${INSTALLER_PATH} ${CRUCIBLE_INSTALL_SRC}
        chmod +x ${INSTALLER_PATH}
    fi
    if [ ${AUTH_TOKEN_FILE_FOUND} == 1 ]; then
        INSTALLER_ARGS+=" --client-server-auth-file ${auth_file}"
        REGISTRY_TLS_VERIFY="true"

        case "${AUTH_TOKEN_TYPE}" in
            "CI")
                CONTAINER_REGISTRY="quay.io/crucible/crucible-ci-engines"
                ;;
            "PRODUCTION")
                CONTAINER_REGISTRY="quay.io/crucible/client-server"
                ;;
        esac
    fi
    CONTROLLER_REGISTRY_ARGS=""
    if [ "${CI_CONTROLLER}" == "yes" ]; then
        CONTROLLER_REGISTRY_ARGS="--controller-registry quay.io/crucible/crucible-ci-controller:${CI_CONTROLLER_TAG}"
    fi
    INSTALLER_CMD="${INSTALLER_PATH} ${CONTROLLER_REGISTRY_ARGS} --client-server-registry ${CONTAINER_REGISTRY} --client-server-tls-verify ${REGISTRY_TLS_VERIFY} --name nobody --email nobody@nobody.nobody.com --verbose ${INSTALLER_ARGS}"
    echo "Running: ${INSTALLER_CMD}"
    ${INSTALLER_CMD}
    RC=$?
    if [ ${RC} != 0 ]; then
        exit ${RC}
    fi

    popd > /dev/null
else
    echo "ERROR: Could not pushd to ~/"
    exit 1
fi
stop_github_group

start_github_group "CI Target Processing"
if [ "${CI_TARGET}" != "none" -a "${CI_TARGET_DIR}" != "none" ]; then
    if [ "${CI_TARGET}" != "crucible" ]; then
        echo "Handling --ci-target=${CI_TARGET} --ci-target-dir=${CI_TARGET_DIR}"

        if pushd /opt/crucible/subprojects > /dev/null; then
            STALE_LINK=$(find . -name ${CI_TARGET} -type l)

            if [ -z "${STALE_LINK}" ]; then
                echo "ERROR: Could not find --ci-target=${CI_TARGET}"
                exit 1
            fi

            if pushd $(dirname ${STALE_LINK}) > /dev/null; then
                echo "Found ${CI_TARGET} in $(pwd)"
                echo "Removing ${CI_TARGET}:"
                rm -v $(basename ${STALE_LINK})
                echo "Creating new symbolic link:"
                ln -sv ${CI_TARGET_DIR} $(basename ${STALE_LINK})

                popd > /dev/null
            else
                echo "ERROR: Could not pushd to $(dirname ${STALE_LINK})"
                exit 1
            fi

            if pushd ${STALE_LINK} > /dev/null; then
                REPO_FILE="/opt/crucible/config/repos.json"
                source /opt/crucible/bin/jqlib
                function exit_error() {
                    echo "ERROR: ${1}"
                    exit 1
                }
                current_repo_location=$(jq_query ${REPO_FILE} --arg repository "${CI_TARGET}" '.official[] | select(.name == $repository) | .repository')
                actual_repo_location=$(git remote get-url origin)
                if [ "${current_repo_location}" != "${actual_repo_location}" ]; then
                    echo "Setting repository for ${CI_TARGET} to '${actual_repo_location}' in ${REPO_FILE}"
                    jq_update ${REPO_FILE} ${CI_TARGET}:repository --arg repository_name "${CI_TARGET}" --arg repository "${actual_repo_location}" '(.official[] | select(.name == $repository_name) | .repository) |= $repository)'
                else
                    echo "The current repository location matches: ${current_repo_location}"
                fi
                echo "Setting primary-branch and checkout.target for ${CI_TARGET} to 'HEAD' in ${REPO_FILE}"
                jq_update ${REPO_FILE} ${CI_TARGET}:primary-branch --arg repository "${CI_TARGET}" --arg primary_branch "HEAD" '(.official[] | select(.name == $repository) | ."primary-branch") |= $primary_branch'
                jq_update ${REPO_FILE} ${CI_TARGET}:checkout.target --arg repository "${CI_TARGET}" --arg checkout_target "HEAD" '(.official[] | select(.name == $repository) | .checkout.target) |= $checkout_target'

                popd > /dev/null
            else
                echo "ERROR: Could not pushd to ${STALE_LINK}"
                exit 1
            fi
        else
            echo "ERROR: Could not pushd to /opt/crucible/subprojects"
            exit 1
        fi
    fi
else
    if [ "${CI_TARGET}" != "none" ]; then
        echo "ERROR: You must set --ci-target-dir when setting --ci-target"
        exit 1
    fi

    if [ "${CI_TARGET_DIR}" != "none" ]; then
        echo "ERROR: You must set --ci-target when setting --ci-target-dir"
        exit 1
    fi
fi
stop_github_group

start_github_group "rickshaw-settings updates"
RICKSHAW_SETTINGS_FILE="/opt/crucible/subprojects/core/rickshaw/rickshaw-settings.json"
UPDATES_REQUIRED=0

if [ "${CI_CONTROLLER}" == "yes" ]; then
    UPDATES_REQUIRED=1
    FORCE_BUILDS="true"
    echo "Updating rickshaw-settings value workshop.force-builds to '${FORCE_BUILDS}' in ${RICKSHAW_SETTINGS_FILE}"

    if jq --indent 4 --arg force_builds "${FORCE_BUILDS}" \
          '.workshop."force-builds" = $force_builds' \
          ${RICKSHAW_SETTINGS_FILE} > ${RICKSHAW_SETTINGS_FILE}.tmp; then
        if mv ${RICKSHAW_SETTINGS_FILE}.tmp ${RICKSHAW_SETTINGS_FILE}; then
            echo "Successfully updated:"
            jq --indent 4 . ${RICKSHAW_SETTINGS_FILE}
        else
            echo "ERROR: Failed to move force-builds"
            exit 1
        fi
    else
        echo "ERROR: Failed to update force-builds"
        exit 1
    fi
fi

if [ "${AUTH_TOKEN_FILE_FOUND}" == 1 -a "${AUTH_TOKEN_TYPE}" == "PRODUCTION" ]; then
    UPDATES_REQUIRED=1
    EXPIRATION_LENGTH="52w"
    echo "Updating rickshaw-settings value quay.image-expiration to '${EXPIRATION_LENGTH}' in ${RICKSHAW_SETTINGS_FILE}"

    if jq --indent 4 --arg expiration_length "${EXPIRATION_LENGTH}" \
          '.quay."image-expiration" = $expiration_length' \
          ${RICKSHAW_SETTINGS_FILE} > ${RICKSHAW_SETTINGS_FILE}.tmp; then
        if mv ${RICKSHAW_SETTINGS_FILE}.tmp ${RICKSHAW_SETTINGS_FILE}; then
            echo "Successfully updated:"
            jq --indent 4 . ${RICKSHAW_SETTINGS_FILE}
        else
            echo "ERROR: Failed to move image-expiration"
            exit 1
        fi
    else
        echo "ERROR: Failed to update image-expiration"
        exit 1
    fi
fi

quay_oauth_token_file="/root/quay-oauth.token"
if [ -e "${quay_oauth_token_file}" -a -s "${quay_oauth_token_file}" ]; then
    if [ ${AUTH_TOKEN_FILE_FOUND} -ne 1 ]; then
        echo "ERROR: Found quay oauth token file but no registry token file"
        exit 1
    else
        UPDATES_REQUIRED=1

        case "${AUTH_TOKEN_TYPE}" in
            "CI")
                QUAY_API_URL="https://quay.io/api/v1/repository/crucible/crucible-ci-engines"
                ;;
            "PRODUCTION")
                QUAY_API_URL="https://quay.io/api/v1/repository/crucible/client-server"
                ;;
        esac

        echo "Updating rickshaw-settings values quay.refresh-expiration.token-file to '${quay_oauth_token_file}' and quay.refresh-expiration.api-url to '${QUAY_API_URL}' in ${RICKSHAW_SETTINGS_FILE}"

        if jq --indent 4 --arg token_file "${quay_oauth_token_file}" --arg api_url "${QUAY_API_URL}" \
              '.quay."refresh-expiration"."token-file" = $token_file | .quay."refresh-expiration"."api-url" = $api_url' \
              ${RICKSHAW_SETTINGS_FILE} > ${RICKSHAW_SETTINGS_FILE}.tmp; then
            if mv ${RICKSHAW_SETTINGS_FILE}.tmp ${RICKSHAW_SETTINGS_FILE}; then
                echo "Succesfully updated:"
                jq --indent 4 . ${RICKSHAW_SETTINGS_FILE}
            else
                echo "ERROR: Failed to move refresh-expiration"
                exit 1
            fi
        else
            echo "ERROR: Failed to update refresh-expiration"
            exit 1
        fi
    fi
fi

if [ ${UPDATES_REQUIRED} -eq 0 ]; then
    echo "No updates required to ${RICKSHAW_SETTINGS_FILE}"
fi
stop_github_group
