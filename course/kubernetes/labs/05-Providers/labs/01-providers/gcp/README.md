# Deploy Kubernetes in Google Cloud Platform

<!-- TOC -->

- [Deploy Kubernetes in Google Cloud Platform](#deploy-kubernetes-in-google-cloud-platform)
    - [Prerequisites](#prerequisites)
        - [Prerequisites for Kubernetes](#prerequisites-for-kubernetes)
            - [kubectl](#kubectl)
                - [kubectl setup on Linux](#kubectl-setup-on-linux)
                - [kubectl setup on Mac](#kubectl-setup-on-mac)
                - [kubectl setup on Windows](#kubectl-setup-on-windows)
        - [Prerequisites for Google Cloud Platform](#prerequisites-for-google-cloud-platform)
            - [Google Cloud SDK](#google-cloud-sdk)
                - [Google Cloud SDK setup for Linux or Mac](#google-cloud-sdk-setup-for-linux-or-mac)
                - [Google Cloud SDK setup for Windows](#google-cloud-sdk-setup-for-windows)
    - [Managed Kubernetes with Google Kubernetes Engine (GKE)](#managed-kubernetes-with-google-kubernetes-engine-gke)
        - [Configure gcloud CLI](#configure-gcloud-cli)
            - [Login into Google Cloud Platform](#login-into-google-cloud-platform)
            - [Create new project for this lab (or use an existing one)](#create-new-project-for-this-lab-or-use-an-existing-one)
            - [Enable billing for the project (if needed)](#enable-billing-for-the-project-if-needed)
            - [Enable Container API for the project](#enable-container-api-for-the-project)
            - [Select the project](#select-the-project)
            - [Select the region](#select-the-region)
        - [Create the GKE Cluster](#create-the-gke-cluster)
        - [Configure `kubectl`](#configure-kubectl)
            - [Get the kubectl credentials](#get-the-kubectl-credentials)
            - [Get information from the Kubernetes cluster](#get-information-from-the-kubernetes-cluster)

<!-- /TOC -->

## Prerequisites

### Prerequisites for Kubernetes

#### kubectl

Use the Kubernetes command-line tool, kubectl, to deploy and manage applications on Kubernetes. Using kubectl, you can inspect cluster resources; create, delete, and update components; and look at your new cluster and bring up example apps.

More information and systems in [kubernetes.io / Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

##### kubectl setup on Linux

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

### Prerequisites for Google Cloud Platform

To run the lab, you will need the `gcloud` cli and a GCP project with Billing and GKE API enabled.

#### Google Cloud SDK

Cloud SDK runs on Linux, Mac OS X, and Windows. It requires Python 2.7.x and doesn't currently support Python 3. Some tools bundled with Cloud SDK have additional requirements.

##### Google Cloud SDK setup for Linux or Mac

```bash
curl -sq https://sdk.cloud.google.com | bash; exec -l $SHELL
```

##### Google Cloud SDK setup for Windows

Download the [Cloud SDK installer](https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe) signed by Google Inc.

More information and systems in [Installing Google Cloud SDK](https://cloud.google.com/sdk/install).

## Managed Kubernetes with Google Kubernetes Engine (GKE)

### Configure gcloud CLI

#### Login into Google Cloud Platform

```bash
gcloud auth login
```

#### Create new project for this lab (or use an existing one)

```bash
gcloud projects create rael-k8s-talks --name 'Project for the GKE cluster'
```

```bash
gcloud projects list
```

#### Enable billing for the project (if needed)

The project should have billing active, set it up from the `gcloud` cli using:

```bash
gcloud beta billing accounts list
```

```bash
gcloud beta billing projects link rael-k8s-talks --billing-account 0X0X0X-0X0X0X-0X0X0X
```

#### Enable Container API for the project

In Google Cloud Platform is necessary to enable the service APIs needed for each project.

```bash
gcloud services enable container
```

#### Select the project

```bash
gcloud config set project k8s-upc
```

#### Select the region

It's always recommended to deploy on the nearest region to the user.

```bash
gcloud config set compute/zone europe-west1
```

The list of available region can be found at [cloud.google.com / Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/) or using `gcloud compute regions list`.

### Create the GKE Cluster

```bash
gcloud container clusters create k8s-gke \
    --zone europe-west1-b \
    --enable-autoscaling \
    --min-nodes 3 \
    --max-nodes 5 \
    --disk-size 64 \
    --disk-type pd-balanced \
    --enable-ip-alias \
    --machine-type n1-standard-1
```

### Configure `kubectl`

### Configure GKE Kubectl context

```bash
gcloud container clusters get-credentials k8s-gke --zone europe-west1-b
```

#### Get information from the Kubernetes cluster

```bash
kubectl cluster-info
```

```bash
kubectl get cs
```

## Deploying applications

### Deploy the Guestbook

#### Apply the Guestbook manifests

```bash
kubectl apply -f ../apps/guestbook/k8s/
```

Expected Output:

```bash
deployment.apps/guestbook created
service/guestbook created
deployment.apps/redis-master created
service/redis-master created
deployment.apps/redis-slave created
service/redis-slave created
```

#### Get the Guestbook pods

```bash
kubectl get pods
```

Expected output:

```bash
NAME                            READY     STATUS              RESTARTS   AGE
guestbook-574c46c86-4vvt9       1/1       Running             0          12s
guestbook-574c46c86-d7bnc       1/1       Running             0          12s
guestbook-574c46c86-qgj6g       1/1       Running             0          12s
redis-master-5d8b66464f-jphkc   0/1       ContainerCreating   0          11s
redis-slave-586b4c847c-gw2lq    0/1       ContainerCreating   0          10s
redis-slave-586b4c847c-m7nc8    0/1       ContainerCreating   0          10s
```

#### Get the Guestbook services

```bash
kubectl get services
```

Expected output:

```bash
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
guestbook      LoadBalancer   10.100.236.49   a7e0fda097d5811e89be902c32f5cb30-939770222.us-west-2.elb.amazonaws.com   80:31540/TCP   2m
kubernetes     ClusterIP      10.100.0.1      <none>                                                                   443/TCP        1h
redis-master   ClusterIP      10.100.153.4    <none>                                                                   6379/TCP       2m
redis-slave    ClusterIP      10.100.27.186   <none>                                                                   6379/TCP       2m
```

#### Delete cluster

```bash
gcloud container clusters delete k8s-gke
```