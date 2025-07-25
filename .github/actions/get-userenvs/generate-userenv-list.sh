#!/bin/bash
# -*- mode: sh; indent-tabs-mode: nil; sh-basic-offset: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=bash

rickshaw_directory=${1}
userenv_filter=${2}

# if proper history is available then checks will be performed to see
# if only a subset (ie. those modified) of userenvs need to be tested.
# a subset will only be tested if the only modifications are to
# userenvs, any modification outside of the userenv scope will force
# all testable userenvs to be included
#
# assume that if the proper history is not available that is because
# the code being examined is not from a submitted PR but from a
# repositories merged branch (ie. upstream or a specific release) --
# meaning test all testable userenvs
diff_cmd_validate="git log HEAD^1"
diff_cmd="git diff --name-only HEAD^1 HEAD"

if pushd ${rickshaw_directory}; then
    excludes=""
    excludes_file="userenvs/ci-excludes.txt"
    if [ -e ${excludes_file} ]; then
        while read userenv; do
            excludes+="${userenv} "
        done < ${excludes_file}
    else
        # historical excludes prior to creation of the excludes file
        excludes="stream8-flexran rhel-ai"
    fi

    all_testable_userenvs=0
    if ${diff_cmd_validate} > /dev/null 2>&1; then
        # history is available -- this must be a rickshaw repository PR
        echo "Rickshaw history is available"

        rickshaw_files_changed=$(${diff_cmd})
        echo "Rickshaw files changed:"
        echo "${rickshaw_files_changed}"
        non_userenv_files_changed=$(echo "${rickshaw_files_changed}" | grep -v "^userenvs/" | wc -l)
        if [ ${non_userenv_files_changed} -gt 0 ]; then
            # the normal / historic behavior will be preserved
            all_testable_userenvs=1
            echo "Non userenv changes are present so reverting to normal behavior"
        fi
    else
        # history is not available
        echo "Rickshaw history is not available"

        all_testable_userenvs=1
    fi

    if [ ${all_testable_userenvs} -eq 1 ]; then
        # get the list of all testable userenvs
        userenvs=$(find userenvs/ -maxdepth 1 -name '*.json' -type f)
    else
        # only generate the list of modified / created userenvs since
        # no other rickshaw changes are present

        # get the list of all testable userenvs
        available_list=$(find userenvs/ -maxdepth 1 -name '*.json' -type f)

        # get the list of modified files
        modified_list=$(${diff_cmd})

        # check if any of the modified files are part of the available
        # list and if they are then it is a testable userenv
        userenvs=""
        for file in ${modified_list}; do
            if echo "${available_list}" | grep -q "${file}"; then
                echo "Found '${file}' in the available list"

                # NOTE: this needs to build a string that is
                # equivalent to the output of find from above -- so 1
                # file per line -- and the $'\n' seems to be the way
                # to create new lines within the string
                userenvs+="${file}"
                userenvs+=$'\n'
            fi
        done
    fi
    userenvs=$(echo "${userenvs}" | sed -e 's|userenvs/||' -e 's|\.json||')

    echo "Initial list of userenvs (pre-exlusion): ${userenvs[@]}"

    # Discard excluded envs
    echo "Excluding userenvs:"
    for ex in ${excludes[@]}; do
        echo "Discarding userenv ${ex} as it is not testable"
        new=( "${userenvs[@]/$ex}" )
        userenvs=$new
    done

    echo "Post exclusion list of userenvs: ${userenvs[@]}"

    userenvs_json="["

    if [ ${all_testable_userenvs} -eq 1 ]; then
        # this is the normal / historic behavior
        echo "Adding userenvs through normal filtering process"

        case "${userenv_filter}" in
            "all"|"minimal")
                userenvs_json+="\"default\","
                echo "Adding 'default' userenv"
                ;;
        esac

        case "${userenv_filter}" in
            "all"|"unique")
                for userenv in ${userenvs}; do
                    userenvs_json+="\"${userenv}\","
                    echo "Adding '${userenv}' userenv"
                done
                ;;
        esac
    else
        # this is the new behavior where only modified / created
        # userenvs are being tested when no other rickshaw changes are
        # present
        echo "Adding userenvs through rickshaw userenv PR process"

        userenv_count=0
        for userenv in ${userenvs}; do
            userenvs_json+="\"${userenv}\","
            echo "Adding '${userenv}' userenv"
            (( userenv_count += 1 ))
        done

        echo "Total userenvs added: ${userenv_count}"

        if [ ${userenv_count} -eq 0 ]; then
            # if we have reached this point then it is likely that a
            # situation has occurred where there no userenvs to test
            # -- for example the current rickshaw PR is only removing
            # a userenv -- so generate a single default userenv to
            # satisify testing requirements
            echo "Adding 'default' userenv since no other userenvs were added"
            userenvs_json+="\"default\","
        fi
    fi

    userenvs_json=$(echo "${userenvs_json}" | sed -e "s/,$//")
    userenvs_json+="]"

    echo "userenvs_json=${userenvs_json}"
    if [ -n "${GITHUB_OUTPUT}" ]; then
        echo "userenvs=${userenvs_json}" >> ${GITHUB_OUTPUT}
    else
        echo "WARNING: \$GITHUB_OUTPUT not defined"
    fi
    exit 0
else
    exit 1
fi
