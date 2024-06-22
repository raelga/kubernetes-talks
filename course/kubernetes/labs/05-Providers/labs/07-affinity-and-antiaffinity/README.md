```
kubectl apply -f hello-node-selector-deployment.yaml
```

### Keep this shell visible

```
watch kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

### Get the node names

```
kubectl get nodes -o name
```

### Add the node name

```
kubectl patch deployment hostname-node-selector -p '{"spec":{"template":{"spec":{"nodeName":"gke-k8s-gke-default-pool-4c243126-zvlt"}}}}'
```

### Test the node affinity

```
kubectl apply -f hostname-affinity-deployment.yaml
```

### Test the node anti-affinity

```
kubectl apply -f hostname-antiaffinity-deployment.yaml
```

### Wrapping up

```
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name
```

```
NODE                                     NAME
gke-k8s-gke-default-pool-e13d7a39-ws50   hostname-affinity-768cfc8fd9-cx645
gke-k8s-gke-default-pool-e13d7a39-ws50   hostname-affinity-768cfc8fd9-mbrpn
gke-k8s-gke-default-pool-e13d7a39-ws50   hostname-affinity-768cfc8fd9-xnl2w
gke-k8s-gke-default-pool-e13d7a39-ptl9   hostname-anti-affinity-7694d88f87-84tpq
gke-k8s-gke-default-pool-e13d7a39-74bs   hostname-anti-affinity-7694d88f87-8jplf
gke-k8s-gke-default-pool-e13d7a39-ws50   hostname-anti-affinity-7694d88f87-hvprs
gke-k8s-gke-default-pool-e13d7a39-74bs   hostname-node-selector-74b5f44c88-tmhr6
```

### Taints and tolerations

```
export TOP_NODE=$(kubectl get pod -o=custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq -c | sort -r | awk '{print $2}' | head -n1)
echo ${TOP_NODE}
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute
```

### Deploy a VIP deployment

```
kubectl apply -f 26-Kubernetes/labs/06-Deployments/labs/07-affinity-and-antiaffinity/hostname-toleration-deployment.yaml
```