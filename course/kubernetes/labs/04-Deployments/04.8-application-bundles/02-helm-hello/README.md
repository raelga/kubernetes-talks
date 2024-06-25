## Install helm

```
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

## Add some helm repositories

```
 helm repo add cloudecho https://cloudecho.github.io/charts/ && \
 helm repo update
```

### Local install

```
helm pull cloudecho/hello --untar
```

```
helm install -n hello-local --create-namespace hello hello/
```

```
helm list -n hello-local
```

```
helm -n hello-local uninstall hello
```

Connect to the App using `port-forward`

```
helm install -n hello-local --create-namespace hello hello/
```

```
export PUBLIC_IP=$(curl -sq http://checkip.amazonaws.com)
export POD_NAME=$(kubectl get pods --namespace hello-local -l "app.kubernetes.io/name=hello,app.kubernetes.io/instance=hello" -o jsonpath="{.items[0].metadata.name}")

export CONTAINER_PORT=$(kubectl get pod --namespace hello-local $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")

echo "Visit http://${PUBLIC_IP}:8080 to use your application"

kubectl --namespace hello-local port-forward --address 0.0.0.0 $POD_NAME 8080:$CONTAINER_PORT
```

### From the repo

```
helm install my-hello cloudecho/hello -n hello --create-namespace --version=0.1.2 --set service.type=LoadBalancer --set service.port=80
```
