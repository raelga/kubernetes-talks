# Helm charts and operators

This lab installs Prometheus and ingress-nginx with Helm, deploys Guestbook, and uses cert-manager to issue a self-signed certificate. Run the commands from this directory.

## Prometheus

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm pull prometheus-community/prometheus --untar
```

Prometheus uses persistent volumes. Kind provides the default `standard` StorageClass. On the AWS Academy EKS stack, mark the existing `gp2` class as default first:

```sh
kubectl annotate storageclass gp2 \
  storageclass.kubernetes.io/is-default-class=true --overwrite
```

Install Prometheus:

```sh
helm upgrade --install prometheus prometheus-community/prometheus \
  --create-namespace --namespace monitoring --wait --timeout=10m
```

## ingress-nginx

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

On EKS, expose the controller through an AWS load balancer:

```sh
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --version 4.15.1 \
  --wait --timeout=10m
kubectl get service ingress-nginx-controller -n ingress-nginx -w
```

On Kind, keep the controller internal and use a port-forward:

```sh
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --version 4.15.1 \
  --set controller.service.type=ClusterIP --wait --timeout=10m
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80
```

## Guestbook

```sh
kubectl apply -f guestbook
kubectl rollout status deployment/redis-master --timeout=300s
kubectl rollout status deployment/redis-slave --timeout=300s
kubectl rollout status deployment/guestbook --timeout=300s
kubectl apply -f guestbook-http-ingress.yaml
```

On EKS, get the ingress controller hostname and send the configured Host header:

```sh
INGRESS_HOST=$(kubectl get service ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${INGRESS_HOST}/" -H 'Host: plain.eks-lab.rael.io'
```

On Kind, keep the port-forward running and use:

```sh
curl http://localhost:8080/ -H 'Host: plain.eks-lab.rael.io'
```

## cert-manager and self-signed TLS

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace --version v1.12.0 \
  --set installCRDs=true --wait --timeout=10m

kubectl apply -f selfsigned-clusterissuer.yaml
kubectl wait --timeout=60s --for=condition=Ready clusterissuer/selfsigned
kubectl wait --timeout=60s -n cert-manager \
  --for=condition=Ready certificate/rael-ca
kubectl wait --timeout=60s --for=condition=Ready clusterissuer/rael-ca

kubectl apply -f guestbook-selfsigned-ingress.yaml
kubectl wait --timeout=180s --for=condition=Ready \
  certificate/ssl.eks-lab.rael.io-cert
```

On EKS:

```sh
curl --insecure "https://${INGRESS_HOST}/" -H 'Host: ssl.eks-lab.rael.io'
```

On Kind, forward HTTPS in another terminal and then connect locally:

```sh
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443
curl --insecure https://localhost:8443/ -H 'Host: ssl.eks-lab.rael.io'
```

## Production certificates

`letsencrypt-production-clusterissuer.yaml` and `guestbook-letsencrypt-production-ingress.yaml` are optional. Before applying them, replace the email and hostnames with values you control and point their public DNS records at the ingress controller. Do not request production certificates for placeholder domains.

## Additional hello application

```sh
helm repo add cloudecho https://cloudecho.github.io/charts/
helm repo update
helm upgrade --install hello cloudecho/hello --version 0.1.2
kubectl apply -f hello+guestbook-selfsigned-ingress.yaml
```

## Cleanup

```sh
kubectl delete -f hello+guestbook-selfsigned-ingress.yaml --ignore-not-found
helm uninstall hello --ignore-not-found
kubectl delete -f guestbook-selfsigned-ingress.yaml --ignore-not-found
kubectl delete -f guestbook --ignore-not-found
kubectl delete -f selfsigned-clusterissuer.yaml --ignore-not-found
helm uninstall cert-manager -n cert-manager
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall prometheus -n monitoring
kubectl delete namespace cert-manager ingress-nginx monitoring --ignore-not-found
```