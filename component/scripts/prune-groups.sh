#!/bin/bash

set -fe
IFS='
'

for user in $( kubectl get user -ojson | jq -r '.items[].metadata.name' )
do
	hasvalidtoken="false"
	for token in $( kubectl get oauthaccesstoken -ojson | jq -r ".items[] | select(.userName == \"$user\") | .metadata.name" )
	do
		if [[ -n "$token" ]]
		then
			created="$( kubectl get oauthaccesstoken "$token" -ojson | jq	-r .metadata.creationTimestamp )"
			expires="$( kubectl get oauthaccesstoken "$token" -ojson | jq	-r .expiresIn )"
			if [[ "$( date -d "$created + $expires seconds" '+%s' )" > "$( date '+%s' )" ]]
			then
				echo "Token is valid."
				hasvalidtoken="true"
			else
				echo "Token is invalid."
			fi
		fi
	done



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
