#!/bin/bash

sudo buildah rm --all
sudo podman system reset --force

echo "Cleaning up registry authorization tokens..."
sudo find /root -name 'crucible-*-engines-token.json' -print -delete
echo "...cleanup complete"

# cleanup the workspace
if [ -n "${GITHUB_WORKSPACE}" ]; then
    if pushd "${GITHUB_WORKSPACE}"; then
	echo "Cleaning up..."
	sudo find ! -name '.' ! -name '..' -delete
	echo "...cleanup complete"
	
	popd
    else
	echo "ERROR: Failed to pushd to '${GITHUB_WORKSPACE}'"
	exit 1
    fi
else
    echo "ERROR: GITHUB_WORKSPACE is not defined"
    exit 1
fi
