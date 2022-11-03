#!/usr/bin/env bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_DIR=$(readlink -e ${SCRIPT_DIR})

source ${SCRIPT_DIR}/base

CI_RUN_ENVIRONMENT="standalone"

longopts="run-environment:"
opts=$(getopt -q -o "" --longoptions "${longopts}" -n "$0" -- "$@")
if [ ${?} -ne 0 ]; then
    echo "ERROR: Unrecognized option specified: $@"
    exit 1
fi
eval set -- "${opts}"
while true; do
    case "${1}" in
        --run-environment)
            shift
            CI_RUN_ENVIRONMENT="${1}"
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

header="Clean CI environment"
start_github_group "${header}"
echo -e "*** ${header} ***\n"
stop_github_group

header="Stopping Crucible Services"
start_github_group "${header}"
echo -e "### ${header} ###\n"
echo
crucible stop es
crucible stop httpd
crucible stop redis
stop_github_group

header="Removing podman resources (containers and images)"
start_github_group "${header}"
echo -e "### ${header} ###\n"
echo
cmd="podman stop --all"
echo "${cmd}"
${cmd}
cmd="podman rm --all"
echo "${cmd}"
${cmd}
cmd="buildah rm --all"
echo "${cmd}"
${cmd}
cmd="podman rmi --all"
echo "${cmd}"
${cmd}
stop_github_group

header="Removing Crucible installed/created files"
start_github_group "${header}"
echo -e "### ${header} ###\n"
echo
cmd="rm -Rfv /opt/crucible* /var/lib/crucible* /etc/sysconfig/crucible  /root/.crucible /etc/profile.d/crucible_completions.sh /home/crucible-containers"
echo "${cmd}"
${cmd}
stop_github_group
