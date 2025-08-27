# Kind Lab

This lab covers setting up a local Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker).

## Prerequisites

- Docker installed and running
- Terminal/command line access

## Install kubectl

### Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### macOS

```bash
# Using Homebrew (recommended)
brew install kubectl

# Or using curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Windows

```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or download directly
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

### Verify kubectl installation

```bash
kubectl version --client
```

## Install kind

### Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.21.0/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
```

### macOS

```bash
# Using Homebrew (recommended)
brew install kind

# Or using curl (Intel)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.21.0/kind-darwin-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind

# Or using curl (Apple Silicon)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.21.0/kind-darwin-arm64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
```

### Windows

```powershell
# Using Chocolatey
choco install kind

# Or download directly
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.21.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe c:\some-dir-in-your-PATH\kind.exe
```

### Verify kind installation

```bash
kind version
```

## Deploy a cluster with kind

### Basic cluster creation

```bash
kind create cluster
```

Expected output:

```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Thanks for using kind! 😊
```

### Advanced cluster options

#### Create cluster with custom name

```bash
kind create cluster --name my-cluster
```

#### Create multi-node cluster

```bash
cat << EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```

#### Create cluster with specific Kubernetes version

```bash
kind create cluster --image kindest/node:v1.28.0
```

### Verify cluster

```bash
# Check cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Check cluster context
kubectl config current-context
```

### Troubleshooting

#### Common issues

- **Docker not running**: Ensure Docker is installed and running
- **Port conflicts**: Kind uses ports 6443, 80, and 443 by default
- **Insufficient resources**: Ensure adequate CPU/memory for Docker

#### Check kind logs

```bash
kind export logs
```

#### Reset cluster

```bash
kind delete cluster
kind create cluster
```

## Cluster Management

### List clusters

```bash
kind get clusters
```

### Delete cluster

```bash
# Delete default cluster
kind delete cluster

# Delete named cluster
kind delete cluster --name my-cluster
```

### Load Docker images into cluster

```bash
# Build and load a local image
docker build -t my-app:latest .
kind load docker-image my-app:latest

# Load from archive
kind load image-archive my-app.tar
```

### Access cluster services

#### Port forwarding

```bash
# Forward local port to pod
kubectl port-forward pod/my-pod 8080:80

# Forward to service
kubectl port-forward service/my-service 8080:80
```

#### Load balancer (using MetalLB)

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Configure IP pool (adjust subnet as needed)
cat << EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

## Next Steps

After setting up your Kind cluster, you can:

- Deploy applications using `kubectl apply`
- Explore Kubernetes resources with `kubectl get`
- Practice with Kubernetes manifests
- Set up monitoring and logging
- Experiment with Helm charts

## Cleanup

To completely remove all Kind clusters and resources:

```bash
# Delete all clusters
kind delete clusters --all

# Remove Kind binary (optional)
sudo rm /usr/local/bin/kind
```
