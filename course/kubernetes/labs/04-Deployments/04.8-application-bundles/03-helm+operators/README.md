
## Visualizing using Prometheus and Grafana

The following steps describe how to setup Prometheus and Grafana to visualize
the progress and performance of a deployment.

### Install Helm3

To install Helm3, follow the instructions provided on their
[website](https://github.com/kubernetes/helm/releases).

### Fetch the Prometheus Chart

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update
```

```
helm pull prometheus-community/prometheus --untar
```

Take some time looking to the downloaded folder

### Install Prometheus

```
helm install prometheus prometheus-community/prometheus \
    --create-namespace --namespace=monitoring
```

### Install NGINX

```
helm install bundles oci://ghcr.io/nginxinc/charts/nginx-ingress --version 0.18.0
```

### Deploy the Guestbook deployment

```
kubectl apply -f guestbook
```

### Deploy the Guestbook Nginx ingress

```
kubectl apply -f guestbook-http-ingress.yaml
```

Check the browser at https://plain.eks-lab.rael.io

### Fetch ExternalDNS

```
helm pull oci://registry-1.docker.io/bitnamicharts/external-dns --untar
```

Take some time looking to the downloaded folder

### Install CertManager

```
helm repo add jetstack https://charts.jetstack.io && helm repo update
```

```
helm pull jetstack/cert-manager --untar
```

Take some time looking to the downloaded folder

```
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.12.0 \
  --set installCRDs=true
```

```
kubectl apply -f selfsigned-clusterissuer.yaml
```

```
kubectl --timeout=10s wait --for=condition=Ready clusterissuers.cert-manager.io selfsigned
kubectl --timeout=10s -n cert-manager wait --for=condition=Ready certificates.cert-manager.io rael-ca
kubectl --timeout=10s wait --for=condition=Ready clusterissuers.cert-manager.io rael-ca
```


### Add SelfSigned TLS to the Guestbook ingress

```
kubectl apply -f guestbook-selfsigned-ingress.yaml
```

### Configure Let's encrypt

```
kubectl apply -f letsencrypt-production-clusterissuer.yaml
```

### Add Let's Encrypt TLS to the Guestbook ingress

```
kubectl apply -f guestbook-letsencrypt-production-ingress.yaml
```

```
kubectl get clusterissuers
```

```
kubectl get certificates,certificaterequests
```

Check the browser at https://ssl.eks-lab.rael.io

### Deploy hello

```
helm install hello cloudecho/hello --create-namespace --version=0.1.2 
```

### Add new app to the ingress

```
kubectl apply -f hello+guestbook-selfsigned-ingress.yaml
```

Check the browser at https://hello.eks-lab.rael.io

### Add the hello app with SSL to the ingress

```
kubectl apply -f hello-selfsigned+guestbook-selfsigned-ingress.yaml 
```

Check the browser at https://hello-ssl.eks-lab.rael.io

### List helm installs

```
helm list --all-namespaces
```