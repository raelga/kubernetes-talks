# How to deploy a Kubernetes Cluster

## Google Cloud Platform

### Prerequisites for GCP

- Login into Google Cloud Platform

```bash
gcloud auth login
```

- Create new project

```bash
gcloud projects create rael-k8s-talks --name 'Project for k8s talk'
```

```bash
gcloud projects list
```

```bash
gcloud config set project
```

```bash
gcloud config set compute/zone asia-northeast1-a
```

- Enable billing for the project

```bash
gcloud beta billing accounts list
```

```bash
gcloud beta billing projects link rael-k8s-talks --billing-account 0X0X0X-0X0X0X-0X0X0X
```

- Enable Container API

```bash
gcloud services enable container
```

### Create GKE Cluster

```bash
gcloud container clusters create bcncloud-gke --num-nodes 2 --machine-type n1-standard-1
```

Get the kubectl credentials

```bash
gcloud container clusters get-credentials bcncloud-gke
```

Get information from the Kubernetes cluster

```bash
kubectl cluster-info
```

```bash
kubectl get cs
```

## Microsoft Azure

### Prerequisites for AKS

- Create resource group

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

## Get nodes

```bash
kubectl get nodes
```

## Amazon Web Services - EKS

- What is `eks`?

Amazon Elastic Container Service for Kubernetes (Amazon EKS) is a managed service that makes it easy for you to run Kubernetes on AWS without needing to stand up or maintain your own Kubernetes control plane. Kubernetes is an open-source system for automating the deployment, scaling, and management of containerized applications.

Amazon EKS runs Kubernetes control plane instances across multiple Availability Zones to ensure high availability. Amazon EKS automatically detects and replaces unhealthy control plane instances, and it provides automated version upgrades and patching for them.

[Amazon Elastic Container Service for Kubernetes
](https://aws.amazon.com/eks/)

### Prerequisites for EKS

- Update AWS CLI

Amazon EKS requires at least version 1.15.32 of the AWS CLI.

```bash
sudo pip install awscli --upgrade
```

- Install heptio-authenticator

Amazon EKS clusters require kubectl and kubelet binaries and the Heptio Authenticator to allow IAM authentication for your Kubernetes cluster. Beginning with Kubernetes version 1.10, you can configure the stock kubectl client to work with Amazon EKS by installing the Heptio Authenticator and modifying your kubectl configuration file to use it for authentication.

```bash
curl -sqo ./heptio-authenticator-aws https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/linux/amd64/heptio-authenticator-aws
sudo install -m 775 -o root -g root heptio-authenticator-aws /usr/local/bin/
rm -v heptio-authenticator-aws
```

More information at [Configure kubectl for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html).

### Deploy the EKS cluster

- Get the VPC information where the EKS will be deployed

```bash
export AWS_EKS_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault].VpcId' --output text)
export AWS_EKS_VPC_SUBNETS_CSV=$(\
    aws ec2 describe-subnets \
    --query "Subnets[?VpcId=='${AWS_EKS_VPC}'] | [?ends_with(AvailabilityZone,'b') || ends_with(AvailabilityZone,'a')].SubnetId" \
    --output text | sed 's/\t/,/g')
env | grep AWS_EKS_VPC
```

- Create EKS Security Group

Before you can create an Amazon EKS cluster, you must create an IAM role that Kubernetes can assume to create AWS resources. For example, when a load balancer is created, Kubernetes assumes the role to create an Elastic Load Balancing load balancer in your account. This only needs to be done one time and can be used for multiple EKS clusters.

```bash
export AWS_EKS_SG_NAME='AmazonEKSSecurityGroup'
export AWS_EKS_SG=$(\
    aws ec2 create-security-group \
    --group-name ${AWS_EKS_SG_NAME} \
    --description "EKS Security Group" \
    --vpc-id ${AWS_EKS_VPC} \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
    --group-name ${AWS_EKS_SG_NAME} \
    --query 'SecurityGroups[].GroupId' \
    --output text)
env | grep AWS_EKS_SG
```

- Create EKS IAM Role

```bash
export AWS_EKS_ROLE_NAME='AmazonEKSServiceRole'
if ! aws iam get-role --role-name ${AWS_EKS_ROLE_NAME} 2>/dev/null; then
aws iam create-role --role-name ${AWS_EKS_ROLE_NAME} --assume-role-policy-document file://aws/eks/AWSServiceRoleForAmazonEKS.json
aws iam attach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
aws iam attach-role-policy --role-name ${AWS_EKS_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
fi
export AWS_EKS_ROLE_ARN=$(aws iam get-role --role-name ${AWS_EKS_ROLE_NAME} --query 'Role.Arn' --output text)
env | grep AWS_EKS_ROLE
```

[Amazon EKS Service IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html)

- Create the EKS cluster

```bash
export AWS_EKS_NAME='bcncloud-eks'
aws eks create-cluster --name ${AWS_EKS_NAME} \
    --role-arn ${AWS_EKS_ROLE_ARN} \
    --resources-vpc-config subnetIds=${AWS_EKS_VPC_SUBNETS_CSV},securityGroupIds=${AWS_EKS_SG} \
    && while true; do aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.endpoint | grep -vq 'null' && break || sleep 10; done;
aws eks describe-cluster --name ${AWS_EKS_NAME}
```

- Check EKS cluster creation status

```bash
export AWS_EKS_ENDPOINT=$(aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.endpoint --output text)
export AWS_EKS_CERTAUTHDATA=$(aws eks describe-cluster --name ${AWS_EKS_NAME} --query cluster.certificateAuthority.data --output text)
```

### Configure EKS Kubectl context

- Install `yq` tool

Install `yq`, like `jq` but for `yml` files. It will be used to create the kubeconfig file for the EKS cluster.

```bash
sudo pip install yq
```

- Create the kube config file for the EKS cluster

```bash
export KUBECTL_EKS_CONTEXT="${AWS_EKS_NAME}.talks.aws.rael.io"
export KUBECTL_EKS_CONTEXT_FILE="${HOME}/.kube/eks/${AWS_EKS_NAME}"
mkdir -p  ~/.kube/eks
yq ".clusters[].cluster.server |= \"${AWS_EKS_ENDPOINT}\" | 
    .clusters[].cluster[\"certificate-authority-data\"] |= \"${AWS_EKS_CERTAUTHDATA}\" |
    .contexts[].name |= \"${KUBECTL_EKS_CONTEXT}\"" \
    aws/eks/EKSKubeConfig.yaml --yaml-output | \
    sed "s/<cluster-name>/${AWS_EKS_NAME}/g" > ${KUBECTL_EKS_CONTEXT_FILE}

# Set the KUBECONFIG env var, add the new KUBECTL_EKS_CONTEXT_FILE just once if needed
[[ -z "${KUBECONFIG}" ]] \
    && export KUBECONFIG=~/.kube/config:${KUBECTL_EKS_CONTEXT_FILE} \
    || export KUBECONFIG="$(echo ${KUBECONFIG} | sed  "s@:${KUBECTL_EKS_CONTEXT_FILE}@@g"):$KUBECTL_EKS_CONTEXT_FILE"
```

More info at [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

- Set kubectl context to ${KUBECTL_EKS_CONTEXT}

```bash
kubectl config use-context ${KUBECTL_EKS_CONTEXT}
```

- Check that is working properly

```bash
kubectl get all
```

### Add some EKS workers

- Amazon EKS-optimized AMI IDs

| Region | Amazon EKS-optimized AMI ID |
|---|---|
| US West (Oregon) (us-west-2) | ami-73a6e20b ||
| US East (N. Virginia) (us-east-1) | ami-dea4d5a1 |

- Create the SSH Public Key for the workers ssh user

```bash
export AWS_EKS_WORKERS_KEY="EKS-${AWS_EKS_NAME}-ec2-key-pair"
aws ec2 create-key-pair --key-name ${AWS_EKS_WORKERS_KEY} \
    --query KeyMaterial --output text > ~/.ssh/eksctl_rsa
```

- Deploy EKS a workers stack

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
    --template-body file://aws/eks/cloudformation-eks-nodegroup.yaml \
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

- Get Workers Instance Role

```bash
export AWS_EKS_WORKERS_ROLE=$(\
    aws cloudformation describe-stacks \
    --stack-name  ${AWS_EKS_WORKERS_STACK} \
    --query "Stacks[].Outputs[?OutputKey=='NodeInstanceRole'].OutputValue" \
    --output text)
env | grep AWS_EKS_WORKERS_ROLE
```

- Apply the AWS authenticator configuration map

```bash
TMP_YML=$(mktemp)
curl -sq 'https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/aws-auth-cm.yaml' | \
    sed "s@\(.*rolearn\):.*@\1: ${AWS_EKS_WORKERS_ROLE}@g" > ${TMP_YML}
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
kubectl apply -f aws/eks/eks-admin-service-account.yaml
```

```bash
kubectl apply -f aws/eks/eks-admin-binding-role.yaml
```

```bash
kubectl proxy
```

```
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

- Create State Bucket

```bash
aws s3api create-bucket \
    --bucket kops-s3.talks.aws.rael.io \
    --region us-east-1
```

- Export KOPS_STATE_STORE env var to avoid having to pass the state param every time

```bash
export KOPS_STATE_STORE=s3://kops-s3.talks.aws.rael.io
```

- Create the SSH Public Key for the kops ssh admin user

```bash
ssh-keygen -t rsa -N '' -b 4086 -C 'kops.talks.aws.rael.io ssh key pair' -f ~/.ssh/kops_rsa
```

- Create the cluster

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
    --yes
```

- Wait for the cluster to be readey

```bash
while true; do kops validate cluster && break || sleep 30; done;
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

- Create the SSH Public Key for the kops ssh admin user

```bash
aws ec2 create-key-pair --key-name EKS-eksctl-key --region us-east-1 --query KeyMaterial --output text > ~/.ssh/eksctl_rsa
```

- Deploy the cluster

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