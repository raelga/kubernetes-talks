# Multiple containers in a Pod

## Network sharing

This command creates a pod with two containers, one running Nginx and the other.

```sh
kubectl apply -f 01-nginx-and-shell-network.yaml
```

The output should be similar to this:

```
pod/nginx-and-shell-network created
```

Then we can run a curl command in the shell container.

```sh
kubectl exec nginx-and-shell-network --container shell --stdin --tty -- /bin/bash
```

```
bash-4.4# curl http://localhost:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

And we can check the logs of the Nginx container.

```sh
kubectl logs nginx-and-shell-network --container nginx --follow
```

Should look like this:

```
127.0.0.1 - - [02/Jul/2024:10:58:50 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
```

## Volume sharing

This command creates a pod with two containers, one running Nginx and the other
running a shell. The shell container has a volume mounted at `/html` that is
shared with the Nginx container.

```sh
kubectl apply -f 02-nginx-and-shell-volume.yaml
```

```
pod/nginx-and-shell-volume created
```

The following command runs a curl command in the container.

```sh
kubectl exec nginx-and-shell-volume --container shell --stdin --tty -- curl localhost
```

The expected output is the 403 error page from Nginx.

```
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.15.11</center>
</body>
</html>
```

Then we can run a shell in the shell container.

```sh
kubectl exec nginx-and-shell-volume --container shell --stdin --tty -- /bin/bash
```

And create a new file in the volume.

```sh

/bin/echo "Hola UPC!" > /html/index.html
```

Now the curl command should return the content of the new file.

```sh
kubectl exec nginx-and-shell-volume --container shell --stdin --tty -- curl localhost
```

```
Hola UPC!
```

## Sidecar pattern

The `03-pod-sidecar.yaml` manifest defines a pod with a webserver container and a content generator sidecar that writes the current date to a shared volume every second.

```sh
kubectl apply -f 03-pod-sidecar.yaml
```

```
pod/pod-multi created
```

Check that both containers are running:

```sh
kubectl get pod pod-multi
```

```
NAME        READY   STATUS    RESTARTS   AGE
pod-multi   2/2     Running   0          5s
```

The content container writes the date to `/html/index.html` every second. We can verify by curling the nginx container:

```sh
kubectl exec pod-multi --container content -- cat /html/index.html
```

Or by port-forwarding to the nginx container:

```sh
kubectl port-forward pod/pod-multi 8080:80 &
curl http://localhost:8080
kill %1
```

The response will show the accumulated date entries written by the sidecar container.

### Cleanup

```sh
kubectl delete -f 01-nginx-and-shell-network.yaml
kubectl delete -f 02-nginx-and-shell-volume.yaml
kubectl delete -f 03-pod-sidecar.yaml
```
