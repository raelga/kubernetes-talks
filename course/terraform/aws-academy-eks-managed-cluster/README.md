# EKS cluster for AWS Academy Account

## Configure AWS credentials

https://awsacademy.instructure.com/courses/64811/modules/items/5739658

```
aws configure set region us-east-1 && nano ~/.aws/credentials
```

Check current user:

```
aws sts get-caller-identity
```

Should look something like:

```
{
    "UserId": "AROAW31NOTSECRET1S4E4:user12345=Rael_Garcia", # notsecret
    "Account": "41231231234",
    "Arn": "arn:aws:sts::41231231234:assumed-role/voclabs/user12345=Rael_Garcia"
}
```

### Ensure you are using your user credentials, and no the instance role `LabRole`.

## Deploy the cluster

It will require about 15 minutes to complete.

```
terraform init; terraform apply;
```

## Configure Kubectl

```
aws eks update-kubeconfig --name lab-eks --region us-east-1
```

Expected output:

```

Added new context arn:aws:eks:us-east-1:471112639378:cluster/lab-eks to /Users/rael/.kube/config

```

```

kubectl cluster-info

```

```

alias k=kubectl

```

```
k cluster-info
```

# Important

Delete all services before destronying the cluster, otherwise ELBs and SG from ELBs will remain.

```
terraform destroy
```
