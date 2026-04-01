#!/usr/bin/env python3
# -*- mode: python; indent-tabs-mode: nil; python-indent-level: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=python

"""
Extract the list of unique endpoints from the crucible-ci configuration.
"""

import argparse
import json
import os
import sys


def process_options():
    parser = argparse.ArgumentParser(description="Get the list of unique endpoints from the CI config")

    parser.add_argument("--rickshaw-directory",
                        dest="rickshaw_directory",
                        help="Path to the rickshaw repository",
                        required=True,
                        type=str)

    parser.add_argument("--benchmark",
                        dest="benchmark",
                        help="Restrict to a specific benchmark",
                        default="all",
                        type=str)

    return parser.parse_args()


def main():
    args = process_options()

    ci_config_file = args.rickshaw_directory + "/util/crucible-ci.json"

    with open(ci_config_file) as fh:
        config = json.load(fh)

    endpoints = set()
    if config["config"]["enabled"]:
        for benchmark in config["benchmarks"]:
            if benchmark["enabled"]:
                if args.benchmark == "all" or args.benchmark == benchmark["name"]:
                    for scenario in benchmark["scenarios"]:
                        if scenario["enabled"]:
                            for endpoint in scenario["endpoints"]:
                                endpoints.add(endpoint)

    result = sorted(endpoints)

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output is not None:
        with open(github_output, "a") as fh:
            fh.write("endpoints=" + json.dumps(result, separators=(",", ":")) + "\n")

    print("Found endpoints: %s" % json.dumps(result, indent=2))

    return 0


if __name__ == "__main__":
    exit(main())
