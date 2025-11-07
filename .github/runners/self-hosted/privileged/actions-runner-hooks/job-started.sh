#!/bin/bash

sudo buildah rm --all
sudo podman rmi --all --force
sudo podman system reset --force

echo "Cleaning up registry authorization tokens..."
sudo find /root -name 'crucible-*-engines-token.json' -print -delete
sudo find /root -name 'quay-oauth.token' -print -delete
echo "...cleanup complete"

echo "Cleaning up SSH key..."
sudo rm -fv /root/.ssh/id_ed25519 /root/.ssh/id_ed25519.pub
echo "...cleanup complete"

toolbox_logged_die_filename="/tmp/toolbox_logged_die.txt"
if [ -e "${toolbox_logged_die_filename}" ]; then
    echo "Found ${toolbox_logged_die_filename}"
    rm -v ${toolbox_logged_die_filename}
fi

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
