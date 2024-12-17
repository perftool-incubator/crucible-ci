#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

runner_type=${1}

case "${runner_type}" in
    "github"|"all")
	endpoints_list="remotehosts k8s"
	;;
    "self")
	endpoints_list="remotehosts"
	;;
    *)
	echo "ERROR: invalid runner type"
	exit 1
	;;
esac

endpoints_json="["
for endpoint in ${endpoints_list}; do
    endpoints_json+="\"${endpoint}\","
done
endpoints_json=$(echo "${endpoints_json}" | sed -e "s/,$//")
endpoints_json+="]"
echo "endpoints_json=${endpoints_json}"
echo
echo "::set-output name=endpoints::${endpoints_json}"
