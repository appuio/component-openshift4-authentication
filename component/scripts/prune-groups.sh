#!/bin/bash

set -feo pipefail
IFS='
'

# NOTE: We use this specific command (which produces the list of users delimited by newlines) in conjunction with the `IFS='\n'` configured above to ensure that the script correctly handles user names that contain a space, since OpenShift allows creating `User` resources which contain a space in `metadata.name`.
for user in $( kubectl get user -ojson | jq -r '.items[].metadata.name' )
do
	hasvalidtoken=$(kubectl get oauthaccesstoken -ojson | \
		jq --arg user "$user" -r '[ .items[] | select(.userName == $user) | (.metadata.creationTimestamp | fromdate) + .expiresIn > now ] | any')

	if $hasvalidtoken
	then
		echo "User $user has a valid token."
	else
		for group in $( kubectl get group -ojson |  jq --arg user "$user" -r '.items[] | select( .users | index($user) ) | .metadata.name' )
		do
			oc adm groups remove-users "$group" "$user"
		done
	fi
	echo
done
