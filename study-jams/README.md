# Kubernetes Study Jam

## 190416-Pods

### What we covered in the Jam?

- Introduction to microservices, docker and container orchestration
- Introduction to Kubernetes Architecture
- Kubernetes Pods

The slide deck is available in:

https://github.com/raelga/kubernetes-talks/tree/master/101

### What we used during the Jam?

```
190416-Pods
├── do
│   ├── Makefile
│   ├── json
│   └── tf
├── docker
│   ├── Makefile
│   └── raelga
└── k8s
    ├── Makefile
    ├── default
    └── kube-system
```

- `do` folder

Contains all the commands required to deploy a cluster in Digital Ocean, but you can run the cluster anywhere. Check the [providers](/providers) for more information.

- `docker` folder

Contains the docker file of the custom images used in the k8s labs.

- `k8s` folder

Contains the kubernetes deployments deployed during the demos, mostly pod manifests for the first session.
