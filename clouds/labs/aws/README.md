# Deploy Kubernetes in AWS

<!-- TOC -->

- [Deploy Kubernetes in AWS](#deploy-kubernetes-in-aws)
    - [Prerequisites](#prerequisites)
        - [Prerequisites for Kubernetes](#prerequisites-for-kubernetes)
            - [Install the kubectl](#install-the-kubectl)
                - [kubectl setup on Linux](#kubectl-setup-on-linux)
                - [kubectl setup on Mac](#kubectl-setup-on-mac)
                - [kubectl setup on Windows](#kubectl-setup-on-windows)
    - [Managed Kubernetes with EKS](#managed-kubernetes-with-eks)
        - [Prerequisites for the EKS deploy](#prerequisites-for-the-eks-deploy)
            - [Update AWS CLI](#update-aws-cli)
            - [Install heptio-authenticator](#install-heptio-authenticator)
                - [Install heptio-authenticator on Linux](#install-heptio-authenticator-on-linux)
                - [Install heptio-authenticator on Mac](#install-heptio-authenticator-on-mac)
        - [Deploy the EKS Cluster](#deploy-the-eks-cluster)
            - [Get the VPC information where the EKS will be deployed](#get-the-vpc-information-where-the-eks-will-be-deployed)
            - [Create EKS Security Group](#create-eks-security-group)
            - [Create EKS IAM Role](#create-eks-iam-role)
            - [Create the EKS cluster](#create-the-eks-cluster)
        - [Configure EKS Kubectl context](#configure-eks-kubectl-context)
            - [Install `yq` tool](#install-yq-tool)
            - [Get the cluster information](#get-the-cluster-information)
            - [Create the kube config file for the EKS cluster](#create-the-kube-config-file-for-the-eks-cluster)
            - [Set kubectl context to `${KUBECTL_EKS_CONTEXT}`](#set-kubectl-context-to-kubectl_eks_context)
            - [Check that is working properly](#check-that-is-working-properly)
        - [Add some EKS workers nodes](#add-some-eks-workers-nodes)
            - [Choose an Amazon EKS-optimized AMI IDs](#choose-an-amazon-eks-optimized-ami-ids)
            - [Deploy EKS a workers stack](#deploy-eks-a-workers-stack)
            - [Get Workers Instance Role](#get-workers-instance-role)
            - [Apply the AWS authenticator configuration map](#apply-the-aws-authenticator-configuration-map)
        - [Deploy Kubernetes Dashboard](#deploy-kubernetes-dashboard)
        - [Cleanup EKS](#cleanup-eks)
    - [Amazon Web Services - eksctl (alpha)](#amazon-web-services---eksctl-alpha)
        - [Prerequisites for eksctl](#prerequisites-for-eksctl)
        - [Deploy eksctl cluster](#deploy-eksctl-cluster)
            - [Create the SSH Public Key for the eksctl admin user](#create-the-ssh-public-key-for-the-eksctl-admin-user)
            - [Deploy the cluster](#deploy-the-cluster)
        - [eksctl cleanup](#eksctl-cleanup)
    - [Amazon Web Services - kops](#amazon-web-services---kops)
        - [Prerequisites for KOPS](#prerequisites-for-kops)
        - [Deploy KOPS cluster](#deploy-kops-cluster)
            - [Create State Bucket](#create-state-bucket)
            - [Create the SSH Public Key for the kops ssh admin user](#create-the-ssh-public-key-for-the-kops-ssh-admin-user)
            - [Create the cluster](#create-the-cluster)

<!-- /TOC -->

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

### Deploy the EKS Cluster

#### Get the VPC information where the EKS will be deployed

```bash
export AWS_EKS_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault].VpcId' --output text)
export AWS_EKS_VPC_SUBNETS_CSV=$(\
    aws ec2 describe-subnets \
    --query "Subnets[?VpcId=='${AWS_EKS_VPC}'] | [?ends_with(AvailabilityZone,'b') || ends_with(AvailabilityZone,'a')].SubnetId" \
    --output text | sed "s/$(printf '\t')/,/g")
env | grep AWS_EKS_VPC
```

> Retrieves the default VPC Id and saves it to the `AWS_EKS_VPC` environment variable.
> Then retrieves the the Ids of subnets for two zones (a, b) for that VPC as comma separated values.
> The list of subnets is stored at the `AWS_EKS_VPC_SUBNETS_CSV` environment variable.

#### Create EKS Security Group

Before you can create an Amazon EKS cluster, you must create an IAM role that Kubernetes can assume to create AWS resources. For example, when a load balancer is created, Kubernetes assumes the role to create an Elastic Load Balancing load balancer in your account. This only needs to be done one time and can be used for multiple EKS clusters.

```bash
export AWS_EKS_SG_NAME='AmazonEKSSecurityGroup'
export AWS_EKS_SG=$(\
    aws ec2 describe-security-groups \
    --group-name ${AWS_EKS_SG_NAME} \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null \
    --group-name ${AWS_EKS_SG_NAME} \
    --description "EKS Security Group" \
    --vpc-id ${AWS_EKS_VPC} \
    --output text 2>/dev/null
)
env | grep AWS_EKS_SG
```

> Set the Security Group name in the `AWS_EKS_SG_NAME` environment variable.
> Then retrieves the Security Group Id for the SG with that name or creates a new one.
> The Security Group Id is stored at `AWS_EKS_SG` environment variable.

#### Create EKS IAM Role

Amazon EKS makes calls to other AWS services on your behalf to manage the resources that you use with the service. Before you can use the service, you must have an IAM policy and role that provides the necessary permissions to Amazon EKS.

More information at [docs.amazon.com / Amazon EKS Service IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html).

```bash
export AWS_EKS_ROLE_NAME='AmazonEKSServiceRole'
if ! aws iam get-role --role-name ${AWS_EKS_ROLE_NAME} 2>/dev/null; then
    aws iam create-role --role-name ${AWS_EKS_ROLE_NAME} --assume-role-policy-document file://eks/iam/AmazonEKSServiceRole.json
    aws iam attach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
    aws iam attach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
fi
export AWS_EKS_ROLE_ARN=$(aws iam get-role --role-name ${AWS_EKS_ROLE_NAME} --query 'Role.Arn' --output text)
env | grep AWS_EKS_ROLE
```

> Set the Role Name to `AWS_EKS_ROLE_NAME` environment variable.
> Then checks if the role `AmazonEKSServiceRole` exists, if not, creates the role using [eks/iam/AmazonEKSServiceRole.json](eks/iam/AmazonEKSServiceRole.json) and attaching the `AmazonEKSServicePolicy` and `AmazonEKSClusterPolicy` managed policies.
> The Role ARN is aftewards stored in `AWS_EKS_ROLE_ARN` environment variable.

More information at [Amazon EKS Service IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html)

#### Create the EKS cluster

Now you can create your Amazon EKS cluster.

> When an Amazon EKS cluster is created, the IAM entity (user or role) that creates the cluster is added to the Kubernetes RBAC authorization table as the administrator. Initially, only that IAM user can make calls to the Kubernetes API server using kubectl. Also, the Heptio Authenticator uses the AWS SDK for Go to authenticate against your Amazon EKS cluster, you must ensure that the same IAM user credentials are in the AWS SDK credential chain when you are running kubectl commands on your cluster.

```bash
export AWS_EKS_NAME='bcncloud-eks'
aws eks create-cluster --name ${AWS_EKS_NAME} \
    --role-arn ${AWS_EKS_ROLE_ARN} \
    --resources-vpc-config subnetIds=${AWS_EKS_VPC_SUBNETS_CSV},securityGroupIds=${AWS_EKS_SG} \
    && while true; do aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.endpoint | grep -vq 'null' && break || sleep 10; done;
aws eks describe-cluster --name ${AWS_EKS_NAME}
```

> Set the cluster name and stores it in `AWS_EKS_NAME` environment variable.
> Creates the cluster with that name using the AWS CLI and all the resource ids obtained on the previous steps: `AWS_EKS_ROLE_ARN`, `AWS_EKS_VPC_SUBNETS_CSV` and `AWS_EKS_SG`.
> Then waits until the cluster endpoint is available and finally describes the EKS cluster.

### Configure EKS Kubectl context

#### Install `jq` tool

`jq` is like sed for JSON data - you can use it to slice and filter and map and transform structured data.

More information and systems in [stedolan.github.io / Install and Set Up jq](https://stedolan.github.io/jq/download/),

##### Install `jq` on Linux

```bash
curl -OL https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo install -m 755 -o root -g root kubectl /usr/local/bin
rm -v jq-linux64
```

##### Install `jq` on Mac

```bash
brew install jq
```

##### Install `jq` on Windows

```bash
chocolatey install jq
```

#### Install `yq` tool

Install `yq`, like `jq` but for `yml` files and requires `jq`. It will be used to create the kubeconfig file for the EKS cluster.

```bash
sudo pip install yq
```

#### Get the cluster information

To create the Kubeconfig file we need the Kubernetes API endpoint and the Certificate Authority data.

```bash
export AWS_EKS_ENDPOINT=$(aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.endpoint --output text)
export AWS_EKS_CERTAUTHDATA=$(aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.certificateAuthority.data --output text)
```

> Gets the Kubernetes endpoint and Certificate Authority data from the EKS resource using the CLI.
> The values are stored at `AWS_EKS_ENDPOINT` and `AWS_EKS_CERTAUTHDATA` environment variables.

More information at [kubernetes.io / Configure Access to Multiple Clusters](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/).

#### Create the kube config file for the EKS cluster

```bash
export KUBECTL_EKS_CONTEXT="${AWS_EKS_NAME}.talks.aws.rael.io"
export KUBECTL_EKS_CONTEXT_FILE="${HOME}/.kube/eks/${AWS_EKS_NAME}"
mkdir -p  ~/.kube/eks
yq ".clusters[].cluster.server |= \"${AWS_EKS_ENDPOINT}\" | 
    .clusters[].cluster[\"certificate-authority-data\"] |= \"${AWS_EKS_CERTAUTHDATA}\" |
    .contexts[].name |= \"${KUBECTL_EKS_CONTEXT}\"" \
    eks/manifests/eks-kubeconfig.yaml --yaml-output | \
    sed "s/<cluster-name>/${AWS_EKS_NAME}/g" > ${KUBECTL_EKS_CONTEXT_FILE}

# Set the KUBECONFIG env var, add the new KUBECTL_EKS_CONTEXT_FILE just once if needed
[[ -z "${KUBECONFIG}" ]] \
    && export KUBECONFIG=~/.kube/config:${KUBECTL_EKS_CONTEXT_FILE} \
    || export KUBECONFIG="$(echo ${KUBECONFIG} | sed  "s@:${KUBECTL_EKS_CONTEXT_FILE}@@g"):$KUBECTL_EKS_CONTEXT_FILE"
```

> Using yq, populates the kubeconfig file with the real information from the EKS cluster, and defines a new context `KUBECTL_EKS_CONTEXT` stored in the `KUBECTL_EKS_CONTEXT_FILE` file. 
> Then updates the `KUBECONFIG` environment variable to allow `kubectl` use the new config file.

More info at [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

#### Set kubectl context to `${KUBECTL_EKS_CONTEXT}`

```bash
kubectl config use-context ${KUBECTL_EKS_CONTEXT}
```

#### Check that is working properly

```bash
kubectl get all
```

### Add some EKS workers nodes

#### Choose an Amazon EKS-optimized AMI IDs

| Region | Amazon EKS-optimized AMI ID |
|---|---|
| US West (Oregon) (us-west-2) | ami-73a6e20b |
| US East (N. Virginia) (us-east-1) | ami-dea4d5a1 |

- Create the SSH Public Key for the workers ssh user

```bash
export AWS_EKS_WORKERS_KEY="EKS-${AWS_EKS_NAME}-ec2-key-pair"
aws ec2 create-key-pair --key-name ${AWS_EKS_WORKERS_KEY} \
    --query KeyMaterial --output text > ~/.ssh/eksctl_rsa
```

#### Deploy EKS a workers stack

```bash
export AWS_EKS_WORKERS_TYPE="t2.small"
export AWS_EKS_WORKERS_AMI="ami-dea4d5a1"
export AWS_EKS_WORKERS_MIN="2"
export AWS_EKS_WORKERS_MAX="4"
export AWS_EKS_WORKERS_KEY="${AWS_EKS_WORKERS_KEY}"
env | grep AWS_EKS_WORKERS
```

```bash
export AWS_EKS_WORKERS_STACK="EKS-${AWS_EKS_NAME}-eks-nodes"

aws cloudformation create-stack \
    --stack-name  ${AWS_EKS_WORKERS_STACK} \
    --capabilities CAPABILITY_IAM \
    --template-body file://eks/cloudformation/eks-nodegroup-cf-stack.yaml \
    --parameters \
        ParameterKey=NodeGroupName,ParameterValue="${AWS_EKS_NAME}-workers" \
        ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue="${AWS_EKS_WORKERS_MIN}" \
        ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue="${AWS_EKS_WORKERS_MAX}" \
        ParameterKey=NodeInstanceType,ParameterValue="${AWS_EKS_WORKERS_TYPE}" \
        ParameterKey=KeyName,ParameterValue="${AWS_EKS_WORKERS_KEY}" \
        ParameterKey=NodeImageId,ParameterValue="${AWS_EKS_WORKERS_AMI}" \
        ParameterKey=ClusterName,ParameterValue="${AWS_EKS_NAME}" \
        ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue="${AWS_EKS_SG}" \
        ParameterKey=VpcId,ParameterValue="${AWS_EKS_VPC}" \
        ParameterKey=Subnets,ParameterValue=\"${AWS_EKS_VPC_SUBNETS_CSV}\" &&
    aws cloudformation wait stack-create-complete --stack-name  ${AWS_EKS_WORKERS_STACK}
```

#### Get Workers Instance Role

```bash
export AWS_EKS_WORKERS_ROLE=$(\
    aws cloudformation describe-stacks \
    --stack-name  ${AWS_EKS_WORKERS_STACK} \
    --query "Stacks[].Outputs[?OutputKey=='NodeInstanceRole'].OutputValue" \
    --output text)
env | grep AWS_EKS_WORKERS_ROLE
```

#### Apply the AWS authenticator configuration map

```bash
TMP_YML=$(mktemp)
sed "s@\(.*rolearn\):.*@\1: ${AWS_EKS_WORKERS_ROLE}@g" eks/manifests/k8s-aws-auth-cm.yaml > ${TMP_YML}
cat ${TMP_YML}
kubectl apply -f ${TMP_YML}
rm -v ${TMP_YML}
```

- Check nodes

```bash
kubectl get nodes
```

### Deploy Kubernetes Dashboard

- Deploy the Kubernetes dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```

- Deploy heapster to enable container cluster monitoring

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
```

- Deploy the influxdb backend for heapster

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
```

- Create the heapster cluster role binding for the dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
```

```bash
kubectl apply -f eks/manifests/eks-admin-service-account.yaml
```

```bash
kubectl apply -f eks/manifests/eks-admin-binding-role.yaml
```

```bash
kubectl proxy
```

```bash
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```

### Cleanup EKS

```bash
aws cloudformation delete-stack --stack-name ${AWS_EKS_WORKERS_STACK}
aws ec2 delete-key-pair --key-name ${AWS_EKS_WORKERS_KEY}
aws eks delete-cluster --name ${AWS_EKS_NAME}
aws ec2 delete-security-group --group-id ${AWS_EKS_SG}
aws iam detach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
aws iam detach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam delete-role --role-name ${AWS_EKS_ROLE_NAME}
```

## Amazon Web Services - eksctl (alpha)

- What is `eksctl`?

`eksctl` is a simple CLI tool for creating clusters on EKS - Amazon's new managed Kubernetes service for EC2. It is written in Go, and based on Amazon's official CloudFormation templates.

You can create a cluster in minutes with just one command – `eksctl create cluster`!

[eksctl - a CLI for Amazon EKS](https://github.com/weaveworks/eksctl)

### Prerequisites for eksctl

```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo install -m 755 -o root -g root /tmp/eksctl /usr/local/bin
```

### Deploy eksctl cluster

#### Create the SSH Public Key for the eksctl admin user

```bash
aws ec2 create-key-pair --key-name EKS-eksctl-key --region us-east-1 --query KeyMaterial --output text > ~/.ssh/eksctl_rsa
```

#### Deploy the cluster

```bash
eksctl create cluster \
    --cluster-name eksctl \
    --region us-east-1 \
    --nodes-min 1 \
    --nodes-max 3 \
    --node-type t2.micro \
    --auto-kubeconfig \
    --ssh-public-key EKS-eksctl-key --verbose 4
```

### eksctl cleanup

```bash
aws ec2 delete-key-pair --key-name EKS-eksctl-key
eksctl delete cluster --cluster-name eksctl
```

## Amazon Web Services - kops

- What is `kops`?

We like to think of it as kubectl for clusters.

kops helps you create, destroy, upgrade and maintain production-grade, highly available, Kubernetes clusters from the command line. AWS (Amazon Web Services) is currently officially supported, with GCE in beta support , and VMware vSphere in alpha, and other platforms planned.

[Kubernetes Operations (kops) - Production Grade K8s Installation, Upgrades, and Management](https://github.com/kubernetes/kops)

### Prerequisites for KOPS

- Linux setup

```bash
wget -O kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x ./kops
sudo mv ./kops /usr/local/bin/
```

More information and systems at [kops install.md](https://github.com/kubernetes/kops/blob/master/docs/install.md)

### Deploy KOPS cluster

#### Create State Bucket

```bash
aws s3api create-bucket \
    --bucket kops-s3.talks.aws.rael.io \
    --region us-east-1
```

- Export KOPS_STATE_STORE env var to avoid having to pass the state param every time

```bash
export KOPS_STATE_STORE=s3://kops-s3.talks.aws.rael.io
```

#### Create the SSH Public Key for the kops ssh admin user

```bash
ssh-keygen -t rsa -N '' -b 4086 -C 'kops.talks.aws.rael.io ssh key pair' -f ~/.ssh/kops_rsa
```

#### Create the cluster

```bash
kops create cluster \
    --name kops.talks.aws.rael.io \
    --master-size t2.micro \
    --master-count 3 \
    --master-zones eu-west-1a,eu-west-1b \
    --node-count 3 \
    --node-size t2.micro \
    --zones eu-west-1a,eu-west-1b \
    --state s3://kops-s3.talks.aws.rael.io \
    --ssh-public-key ~/.ssh/kops_rsa.pub \
    --yes && \
    while true; do kops validate cluster && break || sleep 30; done;
```