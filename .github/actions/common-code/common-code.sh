# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

function process_json() {
    local json=$1; shift

    jq "$@" "${json}" > "${json}.tmp"
    if [ $? == 0 ]; then
        /bin/mv "${json}.tmp" "${json}"
        return 0
    else
        return 1
    fi
}

function start_github_group {
    local header
    header="$@"

    if [ "${CI_RUN_ENVIRONMENT}" == "github" ]; then
        echo "::group::${header}"
    fi
}

function stop_github_group {
    if [ "${CI_RUN_ENVIRONMENT}" == "github" ]; then
        echo "::endgroup::"
    fi
}

function log_rc {
    local rc
    rc=${1}

    if [ "${CI_RUN_ENVIRONMENT}" == "github" ]; then
        if [ ${rc} == 0 ]; then
            echo "::notice::rc=${rc}"
        else
            echo "::error::rc=${rc}"
        fi
    else
        echo "rc=${rc}"
    fi
}

function validate_ci_build_controller {
    case "${CI_BUILD_CONTROLLER}" in
        yes|no)
            echo "CI Build Controller is '${CI_BUILD_CONTROLLER}'"
            echo
            ;;
        *)
            echo "ERROR: Unknown CI_BUILD_CONTROLLER value [${CI_BUILD_CONTROLLER}]"
            exit 1
            ;;
    esac
}

function validate_ci_run_environment {
    case "${CI_RUN_ENVIRONMENT}" in
        standalone|github)
            echo "CI Run Environment is '${CI_RUN_ENVIRONMENT}'"
            echo
            ;;
        *)
            echo "ERROR: Unknown value for --run-environment [${CI_RUN_ENVIRONMENT}].  Acceptable values are 'standalone' and 'github'."
            exit 1
            ;;
    esac
}

function validate_ci_endpoint {
    case "${CI_ENDPOINT}" in
        k8s|kube|remotehosts)
            echo "CI Endpoint is '${CI_ENDPOINT}'"
            echo
            ;;
        *)
            echo "ERROR: Unknown value for --ci-endpoint [${CI_ENDPOINT}].  Acceptable values are 'remotehosts' and 'k8s' or 'kube'."
            exit 1
            ;;
    esac
}

function do_ssh {
    ssh -o PasswordAuthentication=no $@
}

RC_STATUS=0

function run_cmd {
    local cmd rc header force
    cmd=${1}
    shift
    force=${1:-"no"}
    shift

    if [ "${force}" != "no" -o ${RC_STATUS} == 0 ]; then
        header="Running: ${cmd}"
        if [ "${force}" != "no" -a ${RC_STATUS} != 0 ]; then
            header+=" (forced)"
        fi
        start_github_group "${header}"
        echo "${header}"
        echo
        ${cmd}
        rc=${?}

        log_rc ${rc}
        echo
        echo

        if [ ${RC_STATUS} == 0 ]; then
            RC_STATUS=${rc}
        fi

        stop_github_group
    else
        if [ ${CI_VERBOSE} == 1 ]; then
            header="Skipping: ${cmd}"
            start_github_group "${header}"
            echo "${header}"
            echo
            echo
            stop_github_group
        fi
    fi
}

function run_and_capture_cmd {
    local cmd rc header force
    cmd=${1}
    shift
    force=${1:-"no"}
    shift

    if [ "${force}" != "no" -o ${RC_STATUS} == 0 ]; then
        header="Running and capturing: ${cmd}"
        if [ "${force}" != "no" -a ${RC_STATUS} != 0 ]; then
            header+=" (forced)"
        fi
        start_github_group "${header}"
        echo "${header}"
        echo
        captured_output=$(${cmd} | sed -e "/^\*\*\* NOTICE/d" -e "/^$/d")
        rc=${?}
        echo "captured_output:"
        echo ">>>>>"
        echo "${captured_output}"
        echo "<<<<<"

        log_rc ${rc}
        echo
        echo

        if [ ${RC_STATUS} == 0 ]; then
            RC_STATUS=${rc}
        fi

        stop_github_group
    else
        if [ ${CI_VERBOSE} == 1 ]; then
            header="Skipping capture: ${cmd}"
            start_github_group "${header}"
            echo "${header}"
            echo
            echo
            stop_github_group
        fi
    fi
}
