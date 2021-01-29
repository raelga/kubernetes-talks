# Notes

## 0. Create the stack in AWS (Terminal 1)

https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Instances:instanceState=running

```
# 0.1 Deploy the EC2 instance
tf apply
```

## 1. Storage

### Install etcd (Terminal 1)

```
# 1.1 Connect to the EC2 instance with a tunnel for the ECTD port
ssh -L 2379:localhost:2379 $(tf output -raw public_ip)
```

```
# 1.2 Download and unpack the etcd binaries
curl -sqL go.rael.dev/etcd3-3-13 | tar -zxvf -
```

```
# 1.3 Launch the etcd server with a debug flag
~/etcd-v3.3.13-linux-amd64/etcd -debug
```

### Check etcd (Terminal 2)

```
# 1.4 Write some data onto ETCD
etcdctl put /hello "Hello World"
```

```
# 1.5 Read some data from ETCD
etcdctl get /hello
```
(back to the slides)
##  2. Kubernetes API Server

### Download the Kubernetes binaries (Terminal 2)

```
# 2.1 Connect to the EC2 instance with a tunnel for the Kubernetes API port
ssh -L 8080:localhost:8080 $(tf output -raw public_ip)
```

```
# 2.2 We are going to use root to simplify the demo
sudo su -
```

```
# 2.3 Download and unpack the kubernetes binaries
curl -sqL go.rael.dev/k8s1-16-0rc2 | tar -zvxf -
```

### Run the API Server (Terminal 2)

* Keep the Terminal 1 nearby to view that resources are being created.

```
# 2.4 Run the API server using the local etcd launched in 1.3
~/kubernetes/server/bin/kube-apiserver --etcd-servers=http://localhost:2379 --v 3
```

Show the etcd-manager, the core Kubernetes API objects have been created in ETCD.
### Interact with the API Server REST interface  (Terminal 3)

* Keep Terminal 2  nearby to view that requests are being served.
* Remark that api group, version, namespace, kind are part of the path.

```
# 3.1 Check Kubernetes existing objects, for example, configmaps in default ns
curl localhost:8080
```

* Open a browser with the same endpoint

http://localhost:8080

http://localhost:8080/api/v1/namespaces/default/configmaps

* Filter configmaps in the `etcd-manager` interface

### Add a new object using curl   (Terminal 3)

```
# 3.2 Create a new configmap using a HTTP request to the API Server
curl -sq -v -X POST -H "Content-Type: application/json" -d '{ "apiVersion": "v1", "kind": "ConfigMap", "metadata": { "name": "hello-cm" }, "data": { "GREETINGS": "Hello Kubernetes Community Days El Salvador from curl" } }' localhost:8080/api/v1/namespaces/default/configmaps
```

* Refresh the browser with the same configmaps/default endpoint

http://localhost:8080/api/v1/namespaces/default/configmaps

* Check the new configmaps in the `etcd-manager` interface

### Config kubectl   (Terminal 3)

```
#3.3  Create a kubectl config, with the lab-cluster API server listening in localhost:8080 as we already tested above
kubectl config set-cluster lab-cluster --server localhost:8080
kubectl config set-context lab --cluster lab-cluster
kubectl config use-context lab
kubectl cluster-info
```

### Interact with the API using Kubectl (Terminal 3)

```
# 3.4 Retrieve and review the object using kubectl
kubectl get ConfigMaps
kubectl get ConfigMaps/hello-cm -o json
kubectl describe ConfigMaps/hello-cm
```
### Update the object   (Terminal 3)

```
# 3.4 Edit the object using kubectl
kubectl edit hello-cm
```

### Check the updated object using Kubectl (Terminal 3)

```
# 3.4 Retrieve and review the updated bject using kubectl
kubectl get ConfigMaps/hello-cm -o json
kubectl describe ConfigMaps/hello-cm
```
#### Create a deployment (Terminal 3)

* Open the [deployment yaml file](hello-manifests/hello-dep.yml)

* Open the deployments API url for the default namespace, remark how the URL is constructed

http://localhost:8080/apis/apps/v1/namespaces/default/deployments

* Create the deployment using kubectl

```
# 3.5 Create a deployment
kubectl create -f hello-manifests/hello-dep.yml
kubectl get deployments
```

* Open refresh deployments API url for the default namespace

http://localhost:8080/apis/apps/v1/namespaces/default/deployments

* Check the resources created, talk about the status READY and the missing ReplicaSets

```
# 3.6 Create a deployment
kubectl get deployments
kubectl get ReplicaSets
kubectl get all -o wide
```

* Open replicasets API url for the default namespace by changing just the kind, same apps/v1 api.

http://localhost:8080/apis/apps/v1/namespaces/default/replicasets

**What is happening? Why the `ReplicaSets` are not being created?**

* Only the deployment has been created, because the API server is the interface for the etcd storage.
* It's role is to provide an interface to the storage.

```
# 3.7 Leave the Terminal 3 open watching all the resources, refreshing each second
watch -n1 kubectl get all -o wide
```

(back to the slides)
## Controller Manager (Terminal 4)

```
# 4.1 Connect to the EC2 instance, no tunnel is needed this time as the API server is the only thing the client needs access
ssh -t $(tf output -raw public_ip) sudo su -
```

```
# 4.2 Generate the necessary certificates, out of the scope of this talk
~/kubernetes/server/bin/kubeadm init phase certs all
```

* Ensure the Terminal 3 with the 3.7 watch command is visible

```
# 4.3 Launch the kube controller manager, poiting to the kubernetes API server and the certificates. Remark etcd.
~/kubernetes/server/bin/kube-controller-manager --master localhost:8080 --service-account-private-key-file /etc/kubernetes/pki/sa.key --v 5
```

* Stop the watch from Terminal 3 and review what is happening

```
# 4.4
kubectl describe pods
```

* Navigate to the Pods endpoint, first just change the kind and then the api group.

http://localhost:8080/api/v1/namespaces/default/pods

* Filter `pods` in the etcd-manager interface

**What is happening? Why the `Pods` are stuck in `Pending`?**

* The `kubernetes-controller-manager` has several controllers running:
    * Deployment Controller knows that it has to create a replicaset for the deployment, so it creates a replicaset object, stored in etcd.
    * ReplicaSet Controller knows that it has to create a pods for the replicaset, so it creates pods, stored in etcd.
    * The pods exists in etcd but are not being **scheduled**

```
# 3.7 Leave the Terminal 3 open watching all the resources again
watch -n1 kubectl get all -o wide
```

## Kubernetes Scheduler (Terminal 5)

```
# 5.1 Connect to the EC2 instance, no tunnel is needed this time as the API server is the only thing the client needs access
ssh -t $(tf output -raw public_ip) sudo su -
```

* Ensure the Terminal 3 with the 3.7 watch command is visible

```
# 4.3 Launch the kube controller manager, poiting to the kubernetes API server and the certificates. Remark etcd.
~/kubernetes/server/bin/kube-scheduler --master localhost:8080 --v 3
```

```
# 4.4
kubectl describe pods
```

```
# 4.5
kubectl get events
```

```
# 4.5
kubectl get nodes
```

```
# 3.7 Leave the Terminal 3 open watching all the resources again
watch -n1 kubectl get all,nodes -o wide
```
## Kubernetes Node (Terminal 6)

```
# 6.1 Connect to the EC2 instance, no tunnel is needed this time as the API server is the only thing the client needs access
ssh -t $(tf output -raw public_ip) sudo su -
```

```
~/kubernetes/server/bin/kubectl config set-cluster lab-cluster --server localhost:8080; \
~/kubernetes/server/bin/kubectl config set-context lab --cluster lab-cluster; \
~/kubernetes/server/bin/kubectl config use-context lab
```

```
cat ~/.kube/config
```

```
 ~/kubernetes/server/bin/kubelet --register-node --kubeconfig ~/.kube/config
```

```
kubectl logs -l app=hello -c echo -f
```


## Kubernetes Node (Terminal 7)

```
# 6.1 Connect to the EC2 instance, no tunnel is needed this time as the API server is the only thing the client needs access
ssh -t $(tf output -raw public_ip) sudo su -
```

```
iptables -L -t nat
```

```
kube-proxy --master localhost:8080
```

```
iptables -L -t nat
```

