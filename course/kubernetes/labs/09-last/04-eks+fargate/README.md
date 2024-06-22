# Deploy Kubernetes in AWS

## Prerequisites

### Prerequisites for Kubernetes

#### Install the kubectl

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

## Managed Kubernetes with EKS

- What is `eks`?

Amazon Elastic Container Service for Kubernetes (Amazon EKS) is a managed service that makes it easy for you to run Kubernetes on AWS without needing to stand up or maintain yo∂ur own Kubernetes control plane. Kubernetes is an open-source system for automating the deployment, scaling, and management of containerized applications.

Amazon EKS runs Kubernetes control plane instances across multiple Availability Zones to ensure high availability. Amazon EKS automatically detects and replaces unhealthy control plane instances, and it provides automated version upgrades and patching for them.

[Amazon Elastic Container Service for Kubernetes](https://aws.amazon.com/eks/)

### Prerequisites for the EKS deploy

#### Update AWS CLI

Amazon EKS requires at least the version 1.15.32 of the AWS CLI.

```bash
pip install awscli --upgrade
```

#### Install heptio-authenticator

Amazon EKS clusters require kubectl and kubelet binaries and the Heptio Authenticator to allow IAM authentication for your Kubernetes cluster. Beginning with Kubernetes version 1.10, you can configure the stock kubectl client to work with Amazon EKS by installing the Heptio Authenticator and modifying your kubectl configuration file to use it for authentication.

More information at [Configure kubectl for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html).

##### Install heptio-authenticator on Linux

```bash
curl -sqo ./heptio-authenticator-aws https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/linux/amd64/heptio-authenticator-aws
sudo install -m 775 -o root -g root heptio-authenticator-aws /usr/local/bin/
rm -v heptio-authenticator-aws
```

##### Install heptio-authenticator on Mac

```bash
curl -o heptio-authenticator-aws https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws
sudo install -m 775 -o root -g admin heptio-authenticator-aws /usr/local/bin/
rm -v heptio-authenticator-aws
```

## Amazon Web Services - eksctl

- What is `eksctl`?

`eksctl` is a simple CLI tool for creating clusters on EKS - Amazon's new managed Kubernetes service for EC2. It is written in Go, and based on Amazon's official CloudFormation templates.

You can create a cluster in minutes with just one command – `eksctl create cluster`!

[eksctl - a CLI for Amazon EKS](https://github.com/weaveworks/eksctl)

### Prerequisites for eksctl

```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo install -m 755 -o root /tmp/eksctl /usr/local/bin
```

### Deploy eksctl cluster

#### Set region variable for eksctl

```bash
export EKSCTL_CLUSTER_NAME='eksctl'
export EKSCTL_AWS_REGION='eu-west-3'
```

#### Create the SSH Public Key for the eksctl admin user

```bash
aws ec2 create-key-pair --key-name EKS-eksctl-key --region ${EKSCTL_AWS_REGION} --query KeyMaterial --output text > ~/.ssh/eksctl_rsa
```

#### Deploy the cluster

```bash
eksctl create cluster \
    --name ${EKSCTL_CLUSTER_NAME} \
    --region ${EKSCTL_AWS_REGION} \
    --auto-kubeconfig \
    --fargate
```

#### Setup kubectl

```
eksctl utils write-kubeconfig \
    --cluster ${EKSCTL_CLUSTER_NAME} \
    --region ${EKSCTL_AWS_REGION}
```

### Deploy Guestbook in the default NS

```
kubectl apply -f https://raw.githubusercontent.com/raelga/kubernetes-talks/gb/guestbook.yaml
```

Doesn't work as Fargate requires a ALB or a NLB.

```
kubectl patch service guestbook -p '{"spec":{"type":"NodePort"}}' && \
kubectl get service guestbook
```

```
kubectl apply -f guestbook-ingress.yaml
```

```
k get ingress && k describe ingress gb
```

Doesn't work either as AWS Load Balancer is a controller not deployed by default.


#### Install the AWS Load Balancer controller

#### Allow the cluster to use AWS Identity and Access Management (IAM) for service accounts.

```
eksctl utils associate-iam-oidc-provider \
  --cluster ${EKSCTL_CLUSTER_NAME} \
  --region ${EKSCTL_AWS_REGION} \
  --approve
```

#### Create the IAM policy that allows the AWS Load Balancer Controller to make calls to AWS APIs on your behalf.

```
aws iam create-policy \
   --policy-name AWSLoadBalancerControllerIAMPolicy \
   --policy-document file://AWSLoadBalancerController/iam_policy.json
```

#### Create a service account named aws-load-balancer-controller in the kube-system namespace for the AWS Load Balancer Controller.

```
eksctl create iamserviceaccount \
  --cluster ${EKSCTL_CLUSTER_NAME} \
  --region ${EKSCTL_AWS_REGION} \
  --name aws-load-balancer-controller \
  --namespace kube-system \
  --attach-policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

#### Install the AWS Load Balancer Controller

```
helm repo add eks https://aws.github.io/eks-charts && \
helm repo update eks
```

```
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --set clusterName=${EKSCTL_CLUSTER_NAME} \
    --set serviceAccount.create=false \
    --set region=${EKSCTL_AWS_REGION} \
    --set vpcId=$(aws eks describe-cluster --region ${EKSCTL_AWS_REGION} --name eksctl --query 'cluster.resourcesVpcConfig.vpcId' --output text) \
    --set serviceAccount.name=aws-load-balancer-controller \
    -n kube-system
```

#### Review the AWS Load Balancer Controller logs

```
kubectl get pods -n kube-system -w;
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

```
export APP_URL=$(kubectl get ingress gb \
    -o jsonpath="{.status.loadBalancer.ingress[*]['hostname']}") && echo https://${APP_URL}/;
while true; do curl -I ${APP_URL}; sleep 5; done;
echo ${APP_URL}
```

### Install another app: the 2048 game


```
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/examples/2048/2048_full.yaml
```

```
k get pods -n game-2048 -w;
k describe pods -n game-2048
```

Doesn't work as Fargate requires a profile.

```
eksctl create fargateprofile \
    --cluster ${EKSCTL_CLUSTER_NAME} \
    --region ${EKSCTL_AWS_REGION} \
    --name game-2048 \
    --namespace game-2048
```

```
k get pods,nodes -n game-2048 -w;
```

### Add a node group for non-fargate workloads

```
eksctl create nodegroup --managed \
  --cluster ${EKSCTL_CLUSTER_NAME} \
  --region ${EKSCTL_AWS_REGION}
```

### Deploy Guestbook on a non-fargate namespace

```
kubectl create namespace guestbook
kubectl apply -n guestbook -f https://raw.githubusercontent.com/raelga/kubernetes-talks/gb/guestbook.yaml
```

```
k get pods -o wide -n guestbook
```


### eksctl cleanup

```bash
aws iam delete-policy \
  --policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/AWSLoadBalancerControllerIAMPolicy
eksctl delete cluster \
  --name ${EKSCTL_CLUSTER_NAME} \
  --region ${EKSCTL_AWS_REGION}

eksctl delete iamserviceaccount \
  --name aws-load-balancer-controller \
  --cluster ${EKSCTL_CLUSTER_NAME} \
  --region ${EKSCTL_AWS_REGION}
```
