#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

RUNNER_TYPE=""
RUNNER_TAGS=""
BENCHMARK_QUERY=""

longopts="runner-type:,runner-tags:,benchmark:"
opts=$(getopt -q -o "" --longoptions "${longopts}" -n "$0" -- "$@")
if [ ${?} -ne 0 ]; then
    echo "ERROR: Unrecognized option specified: $@"
    exit 1
fi
eval set -- "${opts}"
while true; do
    case "${1}" in
        --runner-type)
            shift
            RUNNER_TYPE="${1}"
            shift
            ;;
        --runner-tags)
            shift
            RUNNER_TAGS="${1}"
            shift
            ;;
        --benchmark)
            shift
            BENCHMARK_QUERY="${1}"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "ERROR: Unexpected argument [${1}]"
            shift
            exit 1
            ;;
    esac
done

case "${RUNNER_TYPE}" in
    "github")
        if [ -n "${RUNNER_TAGS}" ]; then
            echo "ERROR: The 'github' runner type does not support runner tags"
            exit 1
        fi

        echo "Runner type is 'github'"
        ;;
    "self")
        echo "Runner type is 'self'"
        ;;
    *)
        echo "ERROR: Unsupported runner type specified [${RUNNER_TYPE}]"
        exit 1
        ;;
esac

if [ -n "${BENCHMARK_QUERY}" ]; then
    case "${BENCHMARK_QUERY}" in
        "fio"|"uperf"|"iperf"|"oslat"|"cyclictest"|"multi")
            echo "Benchmark is '${BENCHMARK_QUERY}'"
            ;;
        *)
            echo "ERROR: Unsupported benchmark specified [${BENCHMARK_QUERY}]"
            exit 1
            ;;
    esac
else
    echo "No benchmark specified"
fi

function get_scenario() {
    local benchmark endpoint enabled

    endpoint=${1}; shift
    benchmark=${1}; shift
    enabled=${1}; shift

    echo "{ \"endpoint\": \"${endpoint}\", \"benchmark\": \"${benchmark}\", \"enabled\": ${enabled} },"
}

function get_enabled_scenario() {
    local benchmark endpoint

    endpoint=${1}; shift
    benchmark=${1}; shift

    get_scenario "${endpoint}" "${benchmark}" "true"
}

function get_disabled_scenario() {
    local benchmark endpoint

    endpoint=${1}; shift
    benchmark=${1}; shift

    get_scenario "${endpoint}" "${benchmark}" "false"
}

function log_enabled() {
    local benchmark endpoint

    endpoint=${1}; shift
    benchmark=${1}; shift

    echo "Adding enabled scenario: endpoint=${endpoint} benchmark=${benchmark}"
}

function log_disabled() {
    local benchmark endpoint

    endpoint=${1}; shift
    benchmark=${1}; shift

    echo "Adding disabled scenario: endpoint=${endpoint} benchmark=${benchmark}"
}

scenarios_json="["

case "${RUNNER_TYPE}" in
    "github")
        if [ -n "${BENCHMARK_QUERY}" ]; then
            case "${BENCHMARK_QUERY}" in
                "fio"|"uperf"|"iperf"|"multi")
                    for endpoint in "k8s" "remotehosts"; do
                        log_enabled "${endpoint}" "${BENCHMARK_QUERY}"
                        scenarios_json+=$(get_enabled_scenario "${endpoint}" "${BENCHMARK_QUERY}")
                    done
                    ;;
                "oslat"|"cyclictest")
                    for endpoint in "k8s"; do
                        log_enabled "${endpoint}" "${BENCHMARK_QUERY}"
                        scenarios_json+=$(get_enabled_scenario "${endpoint}" "${BENCHMARK_QUERY}")
                    done
                    ;;
            esac
        else
            for endpoint in "k8s" "remotehosts"; do
                case "${endpoint}" in
                    "k8s")
                        for benchmark in "fio" "uperf" "iperf" "oslat" "cyclictest" "multi"; do
                            log_enabled "${endpoint}" "${benchmark}"
                            scenarios_json+=$(get_enabled_scenario "${endpoint}" "${benchmark}")
                        done
                        ;;
                    "remotehosts")
                        for benchmark in "fio" "uperf" "iperf" "multi"; do
                            log_enabled "${endpoint}" "${benchmark}"
                            scenarios_json+=$(get_enabled_scenario "${endpoint}" "${benchmark}")
                        done
                        ;;
                esac
            done
        fi
        ;;
    "self")
        TAG_CPU_PARTITIONING=0
        TAG_REMOTEHOSTS=0

        for RUNNER_TAG in $(echo "${RUNNER_TAGS}" | sed -e "s/,/ /g"); do
            case "${RUNNER_TAG}" in
                "cpu-partitioning")
                    echo "Enabling tag 'cpu-partitioning'"
                    TAG_CPU_PARTITIONING=1
                    ;;
                "remotehosts")
                    echo "Enabling tag 'remotehosts'"
                    TAG_REMOTEHOSTS=1
                    ;;
                *)
                    echo "ERROR: Unknown tag encountered [${RUNNER_TAG}]"
                    exit 1
                    ;;
            esac
        done

        if [ ${TAG_CPU_PARTITIONING} -eq 1 -a ${TAG_REMOTEHOSTS} -eq 1 ]; then
            if [ -n "${BENCHMARK_QUERY}" ]; then
                case "${BENCHMARK_QUERY}" in
                    "oslat"|"cyclictest")
                        for endpoint in "remotehosts"; do
                            log_enabled "${endpoint}" "${BENCHMARK_QUERY}"
                            scenarios_json+=$(get_enabled_scenario "${endpoint}" "${BENCHMARK_QUERY}")
                        done
                        ;;
                    "fio"|"uperf"|"iperf"|"multi")
                        log_disabled "null" "${BENCHMARK_QUERY}"
                        scenarios_json+=$(get_disabled_scenario "null" "${BENCHMARK_QUERY}")
                        ;;
                esac
            else
                for endpoint in "remotehosts"; do
                    case "${endpoint}" in
                        "remotehosts")
                            for benchmark in "oslat" "cyclictest"; do
                                echo "Adding scenario: endpoint=${endpoint} benchmark=${benchmark}"
                                scenarios_json+=$(get_enabled_scenario "${endpoint}" "${benchmark}" )
                            done
                            ;;
                    esac
                done
            fi
        else
            echo "ERROR: Unknown tag combination found [${RUNNER_TAGS}]"
            exit 1
        fi
        ;;
esac


scenarios_json=$(echo "${scenarios_json}" | sed -e "s/,$//")
scenarios_json+="]"

echo "scenarios_json=${scenarios_json}"
if [ -n "${GITHUB_OUTPUT}" ]; then
    echo "scenarios=${scenarios_json}" >> ${GITHUB_OUTPUT}
else
    echo "WARNING: \$GITHUB_OUTPUT not defined"
fi
