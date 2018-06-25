# Deploy Kubernetes in Microsoft Azure

<!-- TOC -->

- [Deploy Kubernetes in Microsoft Azure](#deploy-kubernetes-in-microsoft-azure)
    - [Prerequisites](#prerequisites)
        - [Prerequisites for Kubernetes](#prerequisites-for-kubernetes)
        - [Install the kubectl](#install-the-kubectl)
            - [kubectl setup on Linux](#kubectl-setup-on-linux)
                - [kubectl setup on Mac](#kubectl-setup-on-mac)
                - [kubectl setup on Windows](#kubectl-setup-on-windows)
        - [Prerequisites for Azure](#prerequisites-for-azure)
            - [Install Azure CLI](#install-azure-cli)
                - [Azure CLI setup on Linux and Mac](#azure-cli-setup-on-linux-and-mac)
                - [Azure CLI setup on Windows](#azure-cli-setup-on-windows)
    - [Managed Kubernetes with Azure Kubernetes Service (AKS)](#managed-kubernetes-with-azure-kubernetes-service-aks)
        - [Create resource group](#create-resource-group)
        - [Create AKS Cluster](#create-aks-cluster)
        - [Configure AKS Kubectl context](#configure-aks-kubectl-context)
            - [Get information from the Kubernetes cluster](#get-information-from-the-kubernetes-cluster)
        - [Clean up](#clean-up)

<!-- /TOC -->

## Prerequisites

### Prerequisites for Kubernetes

### Install the kubectl

Use the Kubernetes command-line tool, kubectl, to deploy and manage applications on Kubernetes. Using kubectl, you can inspect cluster resources; create, delete, and update components; and look at your new cluster and bring up example apps.

More information and systems in [kubernetes.io / Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

#### kubectl setup on Linux

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -m 755 -o root -g root kubectl /usr/local/bin
```

##### kubectl setup on Mac

Using [Homebrew](https://brew.sh) package manager.

```bash
brew install kubectl
```

##### kubectl setup on Windows

```powershell
Install-Script -Name install-kubectl -Scope CurrentUser -Force
install-kubectl.ps1
```

### Prerequisites for Azure

#### Install Azure CLI

It's strongly recommend that you use a package manager for the CLI. A package manager makes sure you always get the latest updates, and guarantees the stability of CLI components. Check and see if there is a package for your distribution before installing manually.

More information and systems at [Install Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

##### Azure CLI setup on Linux and Mac

```bash
curl -L https://aka.ms/InstallAzureCli | bash
```

##### Azure CLI setup on Windows

Download the [Azure CLI Installer](https://aka.ms/installazurecliwindows)

## Managed Kubernetes with Azure Kubernetes Service (AKS)

### Create resource group

```bash
export AZ_AKS_NAME='bcncloud-aks'
export AZ_AKS_RG="${AZ_AKS_NAME}-rg"
az group create --name ${AZ_AKS_RG} --location australiaeast
```

### Create AKS Cluster

```bash
az aks create \
    --resource-group ${AZ_AKS_RG} \
    --name ${AZ_AKS_NAME} \
    --node-count 3 \
    --node-vm-size Standard_B2s \
    --generate-ssh-keys
```

### Configure AKS Kubectl context

```bash
az aks get-credentials \
    --resource-group ${AZ_AKS_RG} \
    --name ${AZ_AKS_NAME}
```

#### Get information from the Kubernetes cluster

```bash
kubectl cluster-info
```

```bash
kubectl get cs
```

### Clean up

To remove the resources deployed, remove the resource group.

```bash
az group  delete --resource-group ${AZ_AKS_RG}
```