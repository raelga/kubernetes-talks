SHELL := /bin/bash

MAKEFLAGS := --no-print-directory

# Help

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
		| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

k8s-get-admin-user-token:
	kubectl get -n kube-system -o json secrets \
		| jq -r '.items[] | select (.metadata.annotations."kubernetes.io/service-account.name"=="admin-user") | .data.token' \
		| base64 -d
	@echo

k8s-proxy:
	@echo 'http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy'
	kubectl proxy

k8s-run-toolbox:
	kubectl run -ti toolbox --image raelga/toolbox

k8s-generate-busyboxes:
	$(eval N ?= 100)
	for i in `seq 1 $(N)`; do \
		cat default/pods/busybox-0.yaml \
		| sed "s/busybox-0/busybox-$$i/g" \
		| sed "s/id:\s\"0\"/id: \"$$i\"/g";\
		echo;\
	done | tee default/pods/busybox-$(N).yaml
	@echo

k8s-generate-busyboxes-with-resources:
	$(eval N ?= 10)
	for i in `seq 1 $(N)`; do \
		cat default/pods/busybox-resources-0.yaml \
		| sed "s/busybox-resources-0/busybox-resources-$$i/g" \
		| sed "s/id:\s\"0\"/id: \"$$i\"/g";\
		echo;\
	done | tee default/pods/busybox-resources-$(N).yaml
	@echo
