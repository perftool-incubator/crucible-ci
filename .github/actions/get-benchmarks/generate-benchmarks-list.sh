#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

runner_type=${1}

case "${runner_type}" in
    "all")
	benchmarks_list="fio uperf iperf oslat"
	;;
    "github")
	benchmarks_list="fio uperf iperf oslat"
	;;
    "self")
	benchmarks_list="oslat"
	;;
    *)
	echo "ERROR: invalid runner type"
	exit 1
	;;
esac

benchmarks_json="["
for benchmark in ${benchmarks_list}; do
    benchmarks_json+="\"${benchmark}\","
done
benchmarks_json=$(echo "${benchmarks_json}" | sed -e "s/,$//")
benchmarks_json+="]"
echo "benchmarks_json=${benchmarks_json}"
echo
echo "::set-output name=benchmarks::${benchmarks_json}"
