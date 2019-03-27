# k8s

## Install Traefik v1.0

```
k apply -f kube-system/traefik-v1.0-rbac.yaml
k apply -f kube-system/traefik-v1.0-daemontSet.yaml
k apply -f kube-system/traefik-v1.0-service.yaml
```

Expose it using a LB

```
k diff -f kube-system/traefik-v1.0-service-lb.yaml
```

- Logs

```
k logs -n kube-system -f $(k get pod -n kube-system -l name=traefik-v1 -o name)
```

Expose traefik dashboard using traefik

```
k apply -f kube-system/traefik-v1.0-ingress.yaml
```

Deploy something and expose it throught Traefik

```
k apply -f default/whoami-deployment.yaml
k apply -f default/whoami-service.yaml
k apply -f default/whoami-ingress.yaml
```

Add some authentication

```
htpasswd -c htpasswd-secret traefik
kubectl create secret generic super-secure-password --from-file htpasswd-secret
```


k logs -n kube-system -f $(k get pod -n kube-system -l name=traefik-v2 -o name)