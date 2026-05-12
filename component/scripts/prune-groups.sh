#!/bin/bash

set -feo pipefail
IFS='
'

for user in $( kubectl get user -ojson | jq -r '.items[].metadata.name' )
do
	hasvalidtoken=$(kubectl get oauthaccesstoken -ojson | \
		jq --arg user "$user" -r '[ .items[] | select(.userName == $user) | (.metadata.creationTimestamp | fromdate) + .expiresIn > now ] | any')

	if $hasvalidtoken
	then
		echo "User $user has a valid token."
	else
		for group in $( kubectl get group -ojson |  jq -r ".items[] | select( .users | index(\"$user\") ) | .metadata.name" )
		do
			oc adm groups remove-users "$group" "$user"
		done
	fi
	echo
done
