# Kind Lab

This lab covers setting up a local Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker).

## Contents

- [Prerequisites](#prerequisites)
- [Install kubectl](#install-kubectl) and [kind](#install-kind)
- [Create the multi-node cluster](#basic-cluster-creation)
- [Use NodePort in a demo](#use-the-port-in-a-demo)
- [WordPress and MariaDB](#wordpress-and-mariadb-from-compose-to-kind)
- [Advanced cluster options](#advanced-cluster-options)

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

From this directory, create the default multi-node cluster with one control-plane and two workers. The configuration maps `127.0.0.1:8080` to NodePort `30080` and `127.0.0.1:8081` to NodePort `30081` on the control-plane node. Port mappings require cluster recreation; change the corresponding `hostPort` before creation if either port is occupied.

```bash
kind create cluster --config kind-config.yaml
kubectl get nodes
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

## Use the port in a demo

Create a Service selecting the labels of your application's Pods. Its `nodePort` must match the configuration's **containerPort**, 30080; `targetPort` must match the port on which the application actually listens. For example, for Pods labelled `app: demo` listening on port 80:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo
spec:
  type: NodePort
  selector:
    app: demo
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

Apply the Service alongside your application, wait for its Pods to become Ready, and check the endpoints before testing:

```sh
kubectl get svc demo
kubectl get endpointslices -l kubernetes.io/service-name=demo
curl http://localhost:8080/
```

Only one Service can allocate each NodePort at a time. A second Service can use `nodePort: 30081` and be reached at `http://localhost:8081/`. The Services in these labs reuse these ports, so delete the previous lab's Service before starting another that uses the same NodePort. Multiple requests can reach different ready Pods; distribution is not guaranteed to be even. Unlike a Service NodePort, `kubectl port-forward service/...` selects one Pod for the forwarding session.

If kind runs on a remote EC2 instance, `localhost` above refers to that instance. To access it from your laptop, create an SSH tunnel using the actual user, key and IP from your Terraform output:

```sh
ssh -i /path/to/key.pem -L 8080:localhost:8080 user@EC2_IP
```

Keep the tunnel open and visit `http://localhost:8080/` on your laptop. For direct access from other machines, the listen address and host/cloud firewalls must be configured separately; this example deliberately does not expose the port publicly.

The kind cluster reserves host ports 8080 and 8081 even when no Service uses them. Pod port-forward examples below use `18080` to avoid this conflict.

### WordPress and MariaDB: from Compose to kind

Run the same [WordPress Compose example](../../../containers/labs/03-Docker-Compose/03.1-wordpress/) on the EC2 instance using Kubernetes. The [manifest](wordpress.yaml) creates one Pod with WordPress and MariaDB containers and two PersistentVolumeClaims. The containers share the Pod network, so WordPress reaches MariaDB at `127.0.0.1:3306`.

| Docker Compose | Kubernetes in kind |
| --- | --- |
| WordPress and MariaDB services | Two containers in one Pod |
| Compose network and service names | Shared Pod network and `localhost` |
| Published port | `kubectl port-forward` to the Pod |
| Named volumes | PersistentVolumeClaims |

First observe the node container and the Kubernetes node:

```bash
docker ps
kubectl get nodes
```

The kind node is a Docker container; the WordPress and MariaDB containers run inside that node through its container runtime.

The images come from public registries, so this exercise does not need ECR or registry credentials. The passwords in the manifest are disposable lab examples, **not production secrets**. The Pod is standalone: Kubernetes will not create a replacement if it is deleted.

On the EC2 instance, go to the kind lab directory and inspect the manifest:

```bash
cd ~/kubernetes-talks/course/kubernetes/labs/00-Kind
cat wordpress.yaml
```

With the cluster running and its kubectl context selected, create and inspect the objects:

```bash
until kubectl get serviceaccount default >/dev/null 2>&1; do sleep 2; done
kubectl apply -f wordpress.yaml
kubectl get pod wordpress -o wide
kubectl wait --for=condition=Ready pod/wordpress --timeout=300s
kubectl get pvc
```

The first command waits for Kubernetes to create the default ServiceAccount, which may not exist immediately after cluster creation. Stop it with Ctrl-C if the cluster is unavailable.

Once both containers are running, forward the Pod. MariaDB may still need time to initialize before the installer is ready.

```bash
kubectl port-forward pod/wordpress 18080:80
```

Keep the port-forward terminal open. In a second terminal on the EC2 instance, check the server:

```bash
curl -I http://localhost:18080/
```

To open the WordPress installer on your laptop, create a tunnel in a laptop terminal using the key and EC2 address from the Terraform SSH output:

```bash
ssh -o IdentitiesOnly=yes -i /path/to/terraform-k8s.pem -L 18080:localhost:18080 ec2-user@<EC2_IP>
```

Then open `http://localhost:18080/` on the laptop. If port 18080 is already in use on either machine, choose a free local port and adjust the corresponding command. Stop the tunnel and port-forward with Ctrl-C.

To remove the exercise, run the following from the lab directory. **This deletes both claims and their WordPress and database data.** Deleting the kind cluster also removes its local storage.

```bash
kubectl delete -f wordpress.yaml
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

The Service uses NodePort `30080`, mapped to `localhost:8080` by the cluster configuration. Delete any other Service using that NodePort first.

```bash
curl http://localhost:8080

# Remove the Deployment and Service before another exercise uses the port
kubectl delete -f hello-world-go/deployment.yaml
```

#### Important notes about `imagePullPolicy`

When using local images loaded with `kind load`, the Kubernetes manifest **must** set `imagePullPolicy: Never` (or `IfNotPresent`). Otherwise, Kubernetes will try to pull the image from a remote registry and fail with `ErrImagePull`.

```yaml
containers:
- name: hello-world-go
  image: hello-world-go:latest
  imagePullPolicy: Never  # Required for locally loaded images
```

#### Run the image from the ECR lab

This exercise reuses the Go image pushed in the [ECR lab](../../../containers/labs/02-Docker/02.6-ECR/README.md). It pulls the image on the EC2 host and loads it into kind; the Kubernetes node does not need ECR credentials. The ECR repository and its `v1` image must still exist.

On the EC2 instance, set `REPOSITORY` to your ECR repository URL, authenticate Docker using the ECR lab instructions, and use the default `kind` cluster. The Service uses NodePort `30080` (`localhost:8080`); delete any other Service using it first.

```bash
export REPOSITORY="ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPOSITORY_NAME"
docker pull "$REPOSITORY:v1"
docker tag "$REPOSITORY:v1" ecr-hello:v1
kind load docker-image ecr-hello:v1
kubectl apply -f ecr-hello.yaml
kubectl wait --for=condition=Ready pod/ecr-hello --timeout=120s
kubectl get endpointslices -l kubernetes.io/service-name=ecr-hello
```

In the same terminal, check the application and clean up:

```bash
curl --retry 10 --retry-connrefused --retry-delay 1 -f http://localhost:8080/health
kubectl delete -f ecr-hello.yaml
```

The local `ecr-hello:v1` tag refers to the image pulled from your ECR repository; it does not push or modify the remote image. `imagePullPolicy: Never` makes the node use the image loaded into kind. For a named cluster, add `--name` to `kind load docker-image` and select its kubectl context first. Loading an image does not grant the node access to the ECR registry.

#### Load from archive

```bash
# Save an image to a tar archive
docker save hello-world-go:latest -o hello-world-go.tar

# Load from archive into Kind
kind load image-archive hello-world-go.tar
```

### Access cluster services

Kind nodes run as Docker containers. A `ClusterIP` Service is reachable inside the cluster; use port forwarding for access from the EC2 host. A `NodePort` also needs a host-to-node port mapping configured when creating the kind cluster. `LoadBalancer` Services require an implementation such as MetalLB, and Ingress requires an Ingress controller and a route to it.

For example, apply `ecr-hello.yaml` as described in the ECR exercise above, then forward its Service on the EC2 instance:

```bash
kubectl port-forward service/ecr-hello 8080:80
```

In a second EC2 terminal, run `curl http://localhost:8080/health`. Port forwarding listens on localhost by default. To access it from your laptop, keep the port-forward running and create an SSH tunnel from the laptop using the same key as the Terraform `ssh_cmd`:

```bash
ssh -o IdentitiesOnly=yes -i /path/to/terraform-k8s.pem -L 8080:localhost:8080 ec2-user@<EC2_IP>
```

Open `http://localhost:8080/health` on the laptop. Stop the tunnel and port-forward with Ctrl-C, then remove the Pod and Service with `kubectl delete -f ecr-hello.yaml`.

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
