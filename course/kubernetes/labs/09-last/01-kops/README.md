
## Deploy KOPS cluster

### Create State Bucket

```bash
aws s3api create-bucket \
    --bucket kops-s3.talks.aws.rael.io \
    --region us-east-1
```

- Export KOPS_STATE_STORE and KOPS_CLUSTER_NAME env var to avoid having to pass the state param every time

```bash
export KOPS_CLUSTER_NAME=kops.talks.aws.rael.io
export KOPS_STATE_STORE=s3://kops-s3.talks.aws.rael.io
```

### Create the SSH Public Key for the kops ssh admin user

```bash
ssh-keygen -t rsa -N '' -b 4086 -C 'kops.talks.aws.rael.io ssh key pair' -f ~/.ssh/kops_rsa
```

### Create the cluster

```bash
kops create cluster \
    --name kops.talks.aws.rael.io \
    --master-size m5a.large \
    --master-count 3 \
    --master-zones eu-west-1a,eu-west-1b,eu-west-1c \
    --node-count 3 \
    --node-size m5a.large \
    --zones eu-west-1a,eu-west-1b,eu-west-1c \
    --state s3://kops-s3.talks.aws.rael.io \
    --ssh-public-key ~/.ssh/kops_rsa.pub \
    --yes && \
    while true; do kops validate cluster && break || sleep 30; done;
```

### Kubeconfig

```
kops export kubeconfig
```

### Destroy the cluster once finished

```bash
kops delete cluster --name kops.talks.aws.rael.io --yes
```
