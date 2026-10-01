# Argo CD with Kustomize

The overlays install Argo CD in the `argocd` namespace. Choose one exposure method; applying another overlay updates the same installation.

## LoadBalancer service

```sh
kubectl apply -k argocd/service
kubectl rollout status -n argocd deployment/argocd-server --timeout=300s
```

On EKS, wait for the external hostname:

```sh
kubectl get service argocd-server -n argocd -w
```

Open `https://<EXTERNAL-HOSTNAME>/` and accept the self-signed certificate.

On Kind, use a port-forward instead:

```sh
kubectl port-forward -n argocd service/argocd-server 8080:443
```

Open <https://localhost:8080/> and accept the self-signed certificate.

## NGINX Ingress

This overlay requires ingress-nginx, cert-manager, a ready `letsencrypt-production` ClusterIssuer, and DNS records for the hosts in `argocd/ingress/ingress.yaml`. Change those hosts to domains you control before applying it.

```sh
kubectl apply -k argocd/ingress
kubectl get ingress -n argocd
```

## Initial login

```sh
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

The username is `admin`.

## Cleanup

Delete the overlay that is currently applied:

```sh
kubectl delete -k argocd/service
# or: kubectl delete -k argocd/ingress
```
