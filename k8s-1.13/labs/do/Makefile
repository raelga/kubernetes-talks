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

	@mkdir -p .terraform/kube
	bash --rcfile <( echo 'export KUBECONFIG=`pwd`/.terraform/kube/config' );
tf-k8s-kubeconfig: ## Configures kubectl for accessing the deployed k8s cluster
	terraform output --json | jq -r '.kube_config.value' > $(DO_CLUSTER_KUBECONFIG)

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


