#!/usr/bin/make

# For interactive prompt
SHELL := /bin/bash

.DEFAULT_GOAL := help

DO_CLUSTER_JSON := .kube/do-cluster.json
DO_CLUSTER_KUBECONFIG := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/.kube/do-cluster-config.yaml
export KUBECONFIG=$(DO_CLUSTER_KUBECONFIG)

# Help
help:
	@grep --no-filename -E '^[a-zA-Z_0-9-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.do-api-check:
	@echo 'There will be some checks here'
#	@test ! -d .kube && mkdir -p .kube
#	@test -z ${DO_TOKEN} && echo "Environment variable DO_TOKEN is undefined."
#	@which -q jq || echo "jq tool is required"

do-api-create-cluster: .do-api-check ## Creates the cluster using only the Digital Ocean API
	@curl -sSL -X POST  \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		--data @json/k8s-1.13-cluster.json \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		> $(DO_CLUSTER_JSON)

do-api-get-cluster-id: .do-api-check ## Retrieves the cluster id from Digital Ocean API
	$(eval CLUSTER_NAME := $(shell jq -r '.name' json/k8s-1.13-cluster.json))
	$(eval CLUSTER_ID := $(shell \
		curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		| jq -r --arg CLUSTER_NAME "$(CLUSTER_NAME)" '.kubernetes_clusters[] | select (.name==$$CLUSTER_NAME) | .id' \
	))

do-api-get-clusters: .do-api-check ## Retrieves all clusters information from Digital Ocean API
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DO_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters" \
	| jq '.kubernetes_clusters[] | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-api-get-cluster: .do-api-check do-api-get-cluster-id ## Retrieves the cluster information from Digital Ocean API
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DO_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| jq '.kubernetes_cluster | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-api-delete-cluster: .do-api-check do-api-get-cluster-id ## Deletes the cluster using the Digital Ocean API
	@echo -n "Ready to delete $(CLUSTER_NAME), are you sure? Ctrl+C to cancel " \
	&& read ans
	@curl -sSL -o /dev/null -w "%{http_code}" -X DELETE \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DO_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| grep '204' \
		&& echo "Cluster $(CLUSTER_NAME) deleted." \
		|| echo "Unable to delete $(CLUSTER_NAME) cluster (expected response HTTP 204)"

do-api-k8s-kubeconfig: .do-api-check do-api-get-cluster-id ## Retrieves the kubeconfig from the Digital Ocean API
	@mkdir -p .kube
	@curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)/kubeconfig" > $(DO_CLUSTER_KUBECONFIG)
	@bash --rcfile <(\
		cat ~/.bashrc; \
		echo 'PS1="(\$$(kubectl config current-context)) $$PS1"'; \
		alias k='kubectl'; \
	)

tf-init: ## Installs  terraform providers based on the templates in ./tf/
	terraform init ./tf/

tf-plan: ## Shows the plan for deploying the k8s cluster with terraform
	terraform plan ./tf/

tf-apply: ## Deploys the k8s cluster with terraform (asks for confirmation)
	$(eval plan := $(shell mktemp))
	terraform plan -out $(plan) ./tf/
	@echo -n "Ready to apply $(plan) plan, continue? Ctrl+C to cancel " \
	&& read ans
	terraform apply $(plan)

tf-destroy: ## Destroys the k8s cluster with terraform
	terraform destroy ./tf/
	[[ -f terraform.tfstate ]] && rm terraform.tfstate
	[[ -f terraform.tfstate.backup ]] && rm terraform.tfstate.backup

tf-k8s-kubeconfig: ## Configures kubectl for accessing the deployed k8s cluster
	terraform output --json | jq -r '.kube_config.value' > $(DO_CLUSTER_KUBECONFIG)
	@bash --rcfile <(\
		cat ~/.bashrc; \
		echo 'PS1="(\$$(kubectl config current-context)) $$PS1"'; \
		alias k='kubectl'; \
	)

install-tf-osx: ## Installs terraform in OSX using brew
	@which -s terraform \
		&&	echo "terraform is already installed." \
		||	brew install terraform

install-jq-osx: ## Installs jq in OSX using brew
	@which -s jq \
		&&	echo "jq is already installed." \
		||	brew install jq

# Installs doclt in OSX using brew
install-doctl-osx:
	@which -s doctl \
		&&	echo "doctl is already installed." \
		||	brew install doctl


