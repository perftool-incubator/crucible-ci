# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

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
        remotehost|k8s)
            echo "CI Endpoint is '${CI_ENDPOINT}'"
            echo
            ;;
        *)
            echo "ERROR: Unknown value for --ci-endpoint [${CI_ENDPOINT}].  Acceptable values are 'remotehost' and 'k8s'."
            exit 1
            ;;
    esac
}

function do_ssh {
    ssh -o PasswordAuthentication=no $@
}
