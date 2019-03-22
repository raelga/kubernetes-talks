#!/usr/bin/make

# For interactive prompt
SHELL := /bin/bash

.DEFAULT_GOAL := help

## Installs  terraform providers based on the templates in ./tf/
tf-init:
DO_CLUSTER_JSON := .kube/do-cluster.json
DO_CLUSTER_KUBECONFIG := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/.kube/do-cluster-config.yaml
export KUBECONFIG=$(DO_CLUSTER_KUBECONFIG)
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
k8s-login:
	@mkdir -p .terraform/kube
	bash --rcfile <( echo 'export KUBECONFIG=`pwd`/.terraform/kube/config' );
	terraform output --json | jq -r '.kube_config.value' > $(DO_CLUSTER_KUBECONFIG)

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