# k8s talks

## Configure Google Cloud

### View current auths configured

```bash
gcloud auth list
```

### Login into Google Cloud Engine

```bash
gcloud auth login
```

### Create new project

```bash
gcloud projects create rael-k8s-talks --name 'Project for k8s talk'
```

```bash
gcloud projects list
```

```bash
gcloud config set project
```

```bash
gcloud config set compute/zone europe-west1-b
```

### Enable billing for the project

```bash
gcloud beta billing accounts list
```

```bash
gcloud beta billing projects link rael-k8s-talks --billing-account 0X0X0X-0X0X0X-0X0X0X
```

### Enable Container API

```bash
gcloud services enable container
```

### Issues

#### Encoding issues

```powershell
$env:PYTHONIOENCODING = "UTF-8"
```

## Create dockerized application

```bash
docker build -t gcr.io/rael-k8s-talks/hello-world:v1 .\app\app-v1
```

### Test the dockerized application

```bash
docker run -d -p 9999:9999 gcr.io/rael-k8s-talks/hello-world:v1
```

```bash
curl http://localhost:9999
```

```bash
docker stop $(docker ps -a -q -f 'ancestor=gcr.io/rael-k8s-talks/hello-world:v1')
```

### Configure Google Container Registry auth in docker

```bash
gcloud auth configure-docker
```

```bash
docker push gcr.io/rael-k8s-talks/hello-world:v1
```

### Create cluster

```bash
gcloud container clusters create hello-world-cluster --num-nodes 2 --machine-type n1-standard-1
```

Get the kubectl credentials

```bash
gcloud container clusters get-credentials hello-world-cluster
```

Get information from the Kubernetes cluster

```bash
kubectl cluster-info
```

```bash
kubectl get cs
```

Create a deployment to run the container in the cluster

```bash
kubectl run hello-world --image=gcr.io/rael-k8s-talks/hello-world:v1 --port=9999
```

Get the running deployments

```bash
kubectl get deployments
```

Get the running pods

```bash
kubectl get pods
```

View cluster configuration

```bash
kubectl config view
```

Get cluster events

```bash
kubectl get events
```

Check pod logs

```bash
kubectl logs hello-world-d59b7845b-c857d
```

## Enable external exposing a Port traffic

Create a service to expose the deployment

```bash
kubectl expose deployment hello-world --name hello-world-port --type="NodePort"
```

```bash
kubectl get services
```

```bash
kubectl get service hello-world-port
```

```bash
kubectl get service hello-world-port -o go-template='{{(index .spec.port 0).nodePort}}'
```

```bash
gcloud compute firewall-rules create allow-exposed --allow tcp:30759
```


## Enable external with a Load Balancer traffic

Create a service to expose the deployment

```bash
kubectl expose deployment hello-world --name hello-world-lb --type="LoadBalancer"
```

```bash
kubectl get services
```

```bash
kubectl describe services hello-world
```

Links:

- https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/
- https://kubernetes.io/docs/tasks/access-application-cluster/service-access-application-cluster/

## Scale up the service

```bash
kubectl scale deployment hello-world --replicas=4
```

Links:

- https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/

## Update the application

```bash
kubectl edit deployment hello-world
```

## View dashboard

```bash
kubectl -n kube-system describe $(kubectl -n kube-system get secret -n kube-system -o name | grep namespace) | grep token:
```

```bash
kubectl proxy --port 8080
```

## Delete the cluster

```bash
gcloud container clusters list
```

```bash
gcloud container clusters delete hello-world-cluster
```

```bash
gcloud project delete rael-k8s-talks
```

## Delete the project

```bash
gcloud projects delete rael-k8s-talks
```

## Other links

- https://kubernetes-v1-4.github.io/docs/user-guide/kubectl-cheatsheet/