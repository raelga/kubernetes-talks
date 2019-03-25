
k8s-get-chell-traefik-token:
	kubectl get -n kube-system -o json secrets \
		| jq -r '.items[] | select (.metadata.annotations."kubernetes.io/service-account.name"=="chell-traefik") | .data.token' \
		| base64 -d

k8s-get-chell-traefik-ca:
	kubectl get -n kube-system -o json secrets \
		| jq -r '.items[] | select (.metadata.annotations."kubernetes.io/service-account.name"=="chell-traefik") | .data."ca.crt"' \
		| base64 -d
