#!/usr/bin/make

# For interactive prompt
SHELL := /bin/bash

.DEFAULT_GOAL := help

DO_CLUSTER_KUBECONFIG := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/.kube/do-cluster-config.yaml
export KUBECONFIG=$(DO_CLUSTER_KUBECONFIG)

help: #* Shows this help
	@grep --no-filename -E '^[a-zA-Z_0-9-]+:.*?#\* .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?#\\*"}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.common-checks:  ## Private target to check the targets common requirements
	@test -d $(dir $(DO_CLUSTER_KUBECONFIG)) || mkdir -vp "$(dir $(DO_CLUSTER_KUBECONFIG))"
	@test -n "${DIGITALOCEAN_TOKEN}" || { \
		echo "Environment variable DIGITALOCEAN_TOKEN is undefined."; \
		echo "Get your Digital Ocean API TOKEN at https://cloud.digitalocean.com/account/api/tokens"; \
		exit 1; \
	}
	@which -s jq || { echo "This target requires jq."; exit 1; }

##
## Digital Ocean Native targets
## https://developers.digitalocean.com/documentation/v2/
##

.do-checks: .common-checks ## Private target to check the api targets requirements
	@which -s curl || { echo "This target requires curl."; exit 1; }

do-create-cluster: .do-checks #* Creates the cluster using only the Digital Ocean API
	@curl -sSL -X POST  \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
		--data @json/k8s-1.13-cluster.json \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		| jq '.'

do-get-cluster-id: .do-checks #* Retrieves the cluster id from Digital Ocean API
	$(eval CLUSTER_NAME := $(shell jq -r '.name' json/k8s-1.13-cluster.json))
	$(eval CLUSTER_ID := $(shell \
		curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		| jq -r --arg CLUSTER_NAME "$(CLUSTER_NAME)" '.kubernetes_clusters[] | select (.name==$$CLUSTER_NAME) | .id' \
	))

do-get-clusters: .do-checks #* Retrieves all clusters information from Digital Ocean API
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters" \
	| jq '.kubernetes_clusters[] | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-get-cluster: .do-checks do-get-cluster-id #* Retrieves the cluster information from Digital Ocean API
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| jq '.kubernetes_cluster | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-get-cluster-raw: .do-checks do-get-cluster-id #* Retrieves the cluster information from Digital Ocean API
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| jq '.'

do-delete-cluster: .do-checks do-get-cluster-id #* Deletes the cluster using the Digital Ocean API
	@echo -n "Ready to delete $(CLUSTER_NAME), are you sure? Ctrl+C to cancel " \
	&& read ans
	@curl -sSL -o /dev/null -w "%{http_code}" -X DELETE \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| egrep -sq '20[0-9]' \
		&& echo "Cluster $(CLUSTER_NAME) deleted." \
		|| echo "Unable to delete $(CLUSTER_NAME) cluster (expected response HTTP 20[0-9])"

do-get-k8s-kubeconfig: .do-checks do-get-cluster-id #* Retrieves the kubeconfig from the Digital Ocean API
	@curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)/kubeconfig" > $(DO_CLUSTER_KUBECONFIG)
	@echo "Cluster KUBECONFIG stored in $(DO_CLUSTER_KUBECONFIG)."
	@echo "Update your env with:"
	@echo	" export KUBECONFIG=$(DO_CLUSTER_KUBECONFIG);"
	@echo " export PS1=\"(\$$(kubectl config current-context)) \$$PS1\";"

do-k8s-kubeconfig-bash: do-get-k8s-kubeconfig #* Spawns a shell with the cluster kubeconfig set
	@bash --rcfile <(\
		test -f ~/.bashrc && cat ~/.bashrc; \
		echo 'PS1="(\$$(kubectl config current-context)) $$PS1"'; \
	)

##
## Terraform targets
## https://www.terraform.io/docs/providers/do/index.html
##

.tf-checks: .common-checks  ## Private target to check the terraform targets requirements
	@which -s terraform || { echo "This target requires terraform."; exit 1; }

tf-init: .tf-checks #* Installs  terraform providers based on the templates in ./tf/
	terraform init ./tf/

tf-plan: .tf-checks #* Shows the plan for deploying the k8s cluster with terraform
	terraform plan ./tf/

tf-apply: .tf-checks #* Deploys the k8s cluster with terraform (asks for confirmation)
	$(eval plan := $(shell mktemp))
	terraform plan -out $(plan) ./tf/
	@echo -n "Ready to apply $(plan) plan, continue? Ctrl+C to cancel " \
	&& read ans
	terraform apply $(plan)

tf-destroy: .tf-checks #* Destroys the k8s cluster with terraform
	terraform destroy ./tf/
	test ! -f terraform.tfstate || rm -v terraform.tfstate
	test ! -f terraform.tfstate.backup || rm -v terraform.tfstate.backup

tf-get-k8s-kubeconfig: .do-checks do-get-cluster-id #* Retrieves the kubeconfig from the Digital Ocean API
	terraform output --json | jq -r '.kube_config.value' > $(DO_CLUSTER_KUBECONFIG)
	@echo "Cluster KUBECONFIG stored in $(DO_CLUSTER_KUBECONFIG)."
	@echo "Update your env with:"
	@echo	" export KUBECONFIG=$(DO_CLUSTER_KUBECONFIG);"
	@echo " export PS1=\"(\$$(kubectl config current-context)) \$$PS1\";"

tf-k8s-kubeconfig-bash: . #* Spawns a shell with the cluster kubeconfig set
	@bash --rcfile <(\
		test -f ~/.bashrc && cat ~/.bashrc; \
		echo 'PS1="(\$$(kubectl config current-context)) $$PS1"'; \
	)