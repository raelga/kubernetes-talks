# Notes

## Create the stack in AWS

```
tf apply
```

## ETCD

### Install etcd

```
ssh -L 2379:localhost:2379 $(tf output public_ip)
curl -sqL go.rael.dev/etcd3-3-13 | tar -zxvf -
~/etcd-v3.3.13-linux-amd64/etcd -debug
```

### Check etcd

```
etcdctl put /hello "Hello World"
etcdctl get /hello
```

http://localhost:23790/etcdkeeper/

## Kubernetes API Server

### Download the Kubernetes code

```
ssh -L 8080:localhost:8080 $(tf output public_ip)
sudo su -
curl -sqL go.rael.dev/k8s1-16-0rc2 | tar -zvxf -
```

### Run the API Server

```
 ~/kubernetes/server/bin/kube-apiserver --etcd-servers=http://localhost:2379 --v 3
```

### Check Kubernetes existing objects

```
curl -sq -X GET localhost:8080/api/v1/namespaces/default/configmaps
```
http://localhost:8080/api/v1/namespaces/default/configmaps

### Add a new object

```
curl -sq -v -X POST -H "Content-Type: application/json" -d '{ "apiVersion": "v1", "kind": "ConfigMap", "metadata": { "name": "hello-cm" }, "data": { "GREETINGS": "Hello Cloud Native Barcelona from curl" } }' localhost:8080/api/v1/namespaces/default/configmaps
```

## `kubectl`

### Config kubectl

```
kubectl config set-cluster lab-cluster --server localhost:8080
kubectl config set-context lab --cluster lab-cluster
kubectl config use-context lab
```

### Interact with the API

```
kubectl get ConfigMaps
kubectl get ConfigMaps/hello-cm -o json
kubectl describe ConfigMaps/hello-cm
```

### Update the object

```
kubectl diff -f hello-manifests/hello-cm.json
```

#### Create a deployment

```
kubectl create -f hello-manifests/hello-dep.yml
kubectl get deployments
kubectl get ReplicaSets
kubectl get all -o wide
```

## Controller Manager

```
~/kubernetes/server/bin/kube-controller-manager --master localhost:8080 --service-account-private-key-file /etc/kubernetes/pki/sa.key --v 5
```


## Handy links for the demo

- [AWS EC2 Console](https://eu-west-1.console.aws.amazon.com/ec2/home?region=eu-west-1#Instances:sort=tag:Name)

