#!/usr/bin/make

# For interactive prompt
SHELL := /bin/bash

.DEFAULT_GOAL := help

KUBECONFIG := .kube/config
DO_CLUSTER_JSON := .kube/do-cluster.json

## Creates the cluster using only the Digital Ocean API
do-api-create-cluster:
	@curl -X POST  \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		--data @json/k8s-1.13-cluster.json \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		> $(DO_CLUSTER_JSON)

do-get-cluster-id:
	$(eval CLUSTER_NAME := $(shell jq -r '.name' json/k8s-1.13-cluster.json))
	$(eval CLUSTER_ID := $(shell \
		curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters" \
		| jq -r --arg CLUSTER_NAME "$(CLUSTER_NAME)" '.kubernetes_clusters[] | select (.name==$$CLUSTER_NAME) | .id' \
	))

do-api-get-clusters:
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DO_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters" \
	| jq '.kubernetes_clusters[] | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-api-get-cluster: do-get-cluster-id
	@curl -sSL -X GET \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${DO_TOKEN}" \
	"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)" \
	| jq '. | [ { name: .name, id: .id, status: .status.state, endpoint: .endpoint, creation: .created_at } ]'

do-api-k8s-kubeconfig: do-get-cluster-id
	@mkdir -p .kube
	@curl -sSL -X GET \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${DO_TOKEN}" \
		"https://api.digitalocean.com/v2/kubernetes/clusters/$(CLUSTER_ID)/kubeconfig" > $(KUBECONFIG)
	@bash --rcfile <( echo export KUBECONFIG=$(KUBECONFIG) );

## Installs  terraform providers based on the templates in ./tf/
tf-init:
	terraform init ./tf/

## Shows the plan for deploying the k8s cluster with terraform
tf-plan:
	terraform plan ./tf/

## Deploys the k8s cluster with terraform (asks for confirmation)
tf-apply:
	$(eval plan := $(shell mktemp))
	terraform plan -out $(plan) ./tf/
	@echo -n "Ready to apply $(plan) plan, continue? Ctrl+C to cancel " \
	&& read ans
	terraform apply $(plan)

## Destroys the k8s cluster with terraform
tf-destroy:
	terraform destroy ./tf/
	[[ -f terraform.tfstate ]] && rm terraform.tfstate
	[[ -f terraform.tfstate.backup ]] && rm terraform.tfstate.backup

## Configures kubectl for accessing the deployed k8s cluster
tf-k8s-kubeconfig:
	@mkdir -p .terraform/kube
	terraform output --json | jq -r '.kube_config.value' > .terraform/kube/config
	bash --rcfile <( echo 'export KUBECONFIG=`pwd`/.terraform/kube/config' );

## Installs terraform in OSX using brew
install-tf-osx:
	@which -s terraform \
		&&	echo "terraform is already installed." \
		||	brew install terraform

## Installs jq in OSX using brew
install-jq-osx:
	@which -s jq \
		&&	echo "jq is already installed." \
		||	brew install jq

# Installs doclt in OSX using brew
install-doctl-osx:
	@which -s doctl \
		&&	echo "doctl is already installed." \
		||	brew install doctl

# Help
help:
	@printf "\nusage : make <commands> \n\nthe following commands are available : \n\n"
	@cat Makefile | awk '1;/help:/{exit}' | awk '/##/ { print; getline; print; }' | awk '{ getline x; print x; }1' | awk '{ key=$$0; getline; print key "\t\t\t\t " $$0;}'
	@printf "\n"