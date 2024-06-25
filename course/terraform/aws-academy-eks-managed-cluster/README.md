# EKS cluster for AWS Academy Account

It will require about 15 minutes to complete.

```
tf init; tf apply;
```

# Install Kubectl

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

# Configure Kubectl

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
