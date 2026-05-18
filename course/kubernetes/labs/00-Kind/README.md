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

### Load local Docker images into the cluster

Kind clusters run inside Docker containers and cannot pull images from your local Docker daemon by default. You need to explicitly load local images into the cluster using `kind load docker-image`.

#### Build and load a sample app

A sample Go application is provided in the `hello-world-go/` directory.

```bash
# Build the Docker image locally
docker build -t hello-world-go:latest hello-world-go/

# Load the image into the Kind cluster
kind load docker-image hello-world-go:latest
```

Verify the image is available inside the cluster node:

```bash
docker exec -it kind-control-plane crictl images | grep hello-world-go
```

#### Deploy the sample app

```bash
# Deploy the app and service
kubectl apply -f hello-world-go/deployment.yaml

# Wait for the pods to be ready
kubectl rollout status deployment/hello-world-go

# Check the pods are running
kubectl get pods -l app=hello-world-go
```

#### Test the sample app

```bash
# Port-forward to the service
kubectl port-forward service/hello-world-go 8080:8080 &

# Test the app
curl http://localhost:8080

# Stop port-forwarding
kill %1
```

#### Important notes about `imagePullPolicy`

When using local images loaded with `kind load`, the Kubernetes manifest **must** set `imagePullPolicy: Never` (or `IfNotPresent`). Otherwise, Kubernetes will try to pull the image from a remote registry and fail with `ErrImagePull`.

```yaml
containers:
- name: hello-world-go
  image: hello-world-go:latest
  imagePullPolicy: Never  # Required for locally loaded images
```

#### Load from archive

```bash
# Save an image to a tar archive
docker save hello-world-go:latest -o hello-world-go.tar

# Load from archive into Kind
kind load image-archive hello-world-go.tar
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
