k8s-get-admin-user-token:
	kubectl get -n kube-system -o json secrets \
		| jq -r '.items[] | select (.metadata.annotations."kubernetes.io/service-account.name"=="admin-user") | .data.token' \
		| base64 -d