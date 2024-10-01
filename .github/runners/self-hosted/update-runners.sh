#!/bin/bash

pushd $(dirname $0) > /dev/null

runner_user="manager"

for runner_type in "privileged" "unprivileged"; do
    if pushd ${runner_type}; then
	echo "runner_type=${runner_type}"

	if [ ! -e runners.conf ]; then
	    echo "ERROR: Could not find runners.conf"
	    exit 1
	fi

	for runner_ip in $(cat runners.conf); do
	    echo "runner_ip=${runner_ip}"

	    echo "syncing actions-runner-hooks:"
	    rsync -av --progress --stats --delete actions-runner-hooks ${runner_user}@${runner_ip}:

	    echo "listing actions-runner-hooks:"
	    ssh ${runner_user}@${runner_ip} "ls -l ~/actions-runner-hooks"

	    echo "synching .env:"
	    rsync -av --progress --stats .env ${runner_user}@${runner_ip}:~/actions-runner/.env

	    echo "displaying .env:"
	    ssh ${runner_user}@${runner_ip} "cat ~/actions-runner/.env"

	    echo "restarting the runner:"
	    ssh ${runner_user}@${runner_ip} "sudo reboot"

	    echo "##########################################################"
	done

	popd

	echo "**********************************************************"
    else
	echo "ERROR: Failed to pushd to ${runner_type}"
    fi
done
