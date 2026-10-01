# Helm hello chart

Install Helm 3 by following the [official instructions](https://helm.sh/docs/intro/install/).

## Inspect and install the chart locally

```sh
helm repo add cloudecho https://cloudecho.github.io/charts/
helm repo update
helm pull cloudecho/hello --version 0.1.2 --untar
helm lint hello/
```

```sh
helm upgrade --install hello hello/ \
  --namespace hello-local --create-namespace --wait
helm list --namespace hello-local
```

Access the local release through a port-forward on either EKS or Kind:

```sh
kubectl port-forward --namespace hello-local service/hello 8080:8080
```

Open <http://localhost:8080/>.

Remove the local release:

```sh
helm uninstall hello --namespace hello-local
kubectl delete namespace hello-local
```

## Install directly from the repository

On EKS, expose the chart through an AWS load balancer:

```sh
helm upgrade --install my-hello cloudecho/hello \
  --namespace hello --create-namespace --version 0.1.2 \
  --set service.type=LoadBalancer --set service.port=80 --wait
kubectl get service my-hello --namespace hello -w
```

Open `http://<EXTERNAL-HOSTNAME>/`.

On Kind, keep the service internal and use a port-forward:

```sh
helm upgrade --install my-hello cloudecho/hello \
  --namespace hello --create-namespace --version 0.1.2 --wait
kubectl port-forward --namespace hello service/my-hello 8080:8080
```

Open <http://localhost:8080/>.

## Cleanup

```sh
helm uninstall my-hello --namespace hello
kubectl delete namespace hello
```
