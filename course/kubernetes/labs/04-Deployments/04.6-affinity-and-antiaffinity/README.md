## Node selector

```
kubectl apply -f hostname-node-selector-deployment.yaml
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
kubectl patch deployment hostname-node-selector -p '{"spec":{"template":{"spec":{"nodeName":"ip-10-0-2-161.ec2.internal"}}}}'
```

## Affinity and anti-affinity

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
NODE                         NAME
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-7gvnq
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-m8zjf
ip-10-0-3-172.ec2.internal   hostname-affinity-699bffc99b-ngxqj
ip-10-0-2-244.ec2.internal   hostname-anti-affinity-54dcf744b4-58frh
ip-10-0-3-172.ec2.internal   hostname-anti-affinity-54dcf744b4-6jdlb
ip-10-0-3-172.ec2.internal   hostname-anti-affinity-54dcf744b4-ltsz5
ip-10-0-2-244.ec2.internal   hostname-node-selector-8668c8cb75-wk7n6
```

## Taints and tolerations

### Get node with most number of pods

```
export TOP_NODE=$(kubectl get pod -o=custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq -c | sort -r | awk '{print $2}' | head -n1)
echo ${TOP_NODE}
```

### Run this command in a visible shell

```
kubectl get pods -o wide -w
```

### Taint the node

```
kubectl taint nodes ${TOP_NODE} area=vip:NoExecute
```

### Describe the node

```
kubectl describe node ${TOP_NODE}
```

### Review what happened to the pods

```
kubectl get pods -o wide
```

### Deploy a VIP deployment

```
kubectl apply -f hostname-toleration-deployment.yaml
```

### Cleanup

```
kubectl delete -f .
```
