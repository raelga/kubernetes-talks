# DryRun test

k apply --dry-run -f k8s/kube-system/kubernetes-dashboard.yaml
❯ k apply --dry-run -f kube-system/kubernetes-dashboard.yaml

```
secret/kubernetes-dashboard-certs created (dry run)
secret/kubernetes-dashboard-csrf created (dry run)
serviceaccount/kubernetes-dashboard created (dry run)
role.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created (dry run)
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created (dry run)
deployment.apps/kubernetes-dashboard created (dry run)
service/kubernetes-dashboard created (dry run)
```

```
❯ k apply --dry-run -f kube-system/kubernetes-dashboard.yaml

secret/kubernetes-dashboard-certs created (dry run)
secret/kubernetes-dashboard-csrf created (dry run)
serviceaccount/kubernetes-dashboard created (dry run)
role.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created (dry run)
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created (dry run)
deployment.apps/kubernetes-dashboard created (dry run)
service/kubernetes-dashboard created (dry run)
```

```
❯ k proxy
Starting to serve on 127.0.0.1:8001
```

http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy