# Talks

## Kubernetes 101

The main subject of this talk is to have an overview on the microservices architectures. Then, starts an introduction to the kubernetes architecture, core services and objects: pods, controllers, deployments and sets.

- [Kubernetes 101 Slides](https://talks.godoc.org/github.com/raelga/kubernetes-talks/101/kubernetes-101.slide)
- [Kubernetes 101 Slides Source](101/)

## Kubernetes from Scratch

The main subject of this talk is understanding the Kubernetes Control Plane by spinning up a cluster, component by component.

- [Kubernetes from scratch Slides](https://go.rael.dev/cnbcn-extending-k8s)
- [Kubernetes from scratch Lab](https://github.com/raelga/kubernetes-talks/tree/master/k8s-from-scratch)

## Kubernetes Clouds

The main subject of this talk is viewing the differences between each managed kubernetes solution offered by AWS, Azure and GCP.

- [Kubernetes Clouds Slides](https://talks.godoc.org/github.com/raelga/kubernetes-talks/clouds/kubernetes-clouds.slide)
- [Kubernetes Clouds Slides](clouds/)

For the labs, the main object is having several clusters deployed all over the using each managed (or not) solution and deploy the same application using the common interface provided by Kubernetes.

- [Deploy Kubernetes in Amazon Web services](clouds/labs/aws/#deploy-kubernetes-in-aws)
  - [AWS managed Kubernetes with EKS](clouds/labs/aws/#managed-kubernetes-with-eks)
  - [AWS managed Kubernetes with EKS using eksctl](clouds/labs/aws/#amazon-web-services---eksctl-alpha)
  - [AWS non-managed on EC2 with Kops](clouds/labs/aws/#amazon-web-services---kops)
- [Deploy Kubernetes in Google Cloud Platform](clouds/labs/gcp/#deploy-kubernetes-in-google-cloud-platform)
  - [GCP managed Kubernetes with GKE](clouds/labs/gcp/#managed-kubernetes-with-google-kubernetes-engine-gke)
- [Deploy Kubernetes in Azure](clouds/labs/azure/#deploy-kubernetes-in-microsoft-azure)
  - [Azure managed Kubernetes with AKS](clouds/labs/azure/#managed-kubernetes-with-azure-kubernetes-service-aks)

## Providers

### Digital Ocean

The main subject of this talk is introducing to the Digital Ocean cloud platform and their Managed Kubernetes solution.

- [Digital Ocean Slides](https://talks.godoc.org/github.com/raelga/kubernetes-talks/providers/do/digital-ocean.slide)
- [Digital Ocean Slides Source](providers/do/)

## Tools

### Traefik

The main subject of this talk is introducing to the Traefik awesome Cloud Native Edge Router and the new features comming in Traefik 2.0.

- [Traefik Slides](https://talks.godoc.org/github.com/raelga/kubernetes-talks/traefik/traefik.slide)
- [Traefik Slides Source](traefik/)

# Study Jams

- [`ReplicaSets`](study-jams/k8s/default/replicasets/#replicasets)
  - [Introduction](study-jams/k8s/default/replicasets/#introduction)
    - [Learn more](study-jams/k8s/default/replicasets/#learn-more)
    - [Some notes](study-jams/k8s/default/replicasets/#some-notes)
  - [1 - Create a `ReplicaSet`](study-jams/k8s/default/replicasets/#1---create-a-replicaset)
  - [2 - Scaling `ReplicaSets`](study-jams/k8s/default/replicasets/#2---scaling-replicasets)
    - [Double the numbers of replicas with `kubectl scale`](study-jams/k8s/default/replicasets/#double-the-numbers-of-replicas-with-kubectl-scale)
    - [Scale back to 1 replica](study-jams/k8s/default/replicasets/#scale-back-to-1-replica)
    - [Update the `ReplicaSet` with the yaml definition](study-jams/k8s/default/replicasets/#update-the-replicaset-with-the-yaml-definition)
    - [Scale to 50 replicas](study-jams/k8s/default/replicasets/#scale-to-50-replicas)
    - [Scale down back to 5 replicas](study-jams/k8s/default/replicasets/#scale-down-back-to-5-replicas)
  - [3 - Selectors and Pods](study-jams/k8s/default/replicasets/#3---selectors-and-pods)
    - [Deploy some **blue** pods](study-jams/k8s/default/replicasets/#deploy-some-blue-pods)
    - [Deploy a **blue** `ReplicaSet`](study-jams/k8s/default/replicasets/#deploy-a-blue-replicaset)
    - [Run a _red_ pod](study-jams/k8s/default/replicasets/#run-a-red-pod)
    - [`ReplicaSet` for non-colored `pods` only](study-jams/k8s/default/replicasets/#replicaset-for-non-colored-pods-only)
    - [Let's acquire those fancy orange `pods`](study-jams/k8s/default/replicasets/#lets-acquire-those-fancy-orange-pods)
    - [Remove a pod from the orange replicaset](study-jams/k8s/default/replicasets/#remove-a-pod-from-the-orange-replicaset)
    - [Clean up](study-jams/k8s/default/replicasets/#clean-up)
  - [4 - Container probes](study-jams/k8s/default/replicasets/#4---container-probes)
    - [Readiness probe](study-jams/k8s/default/replicasets/#readiness-probe)
    - [Liveness probe](study-jams/k8s/default/replicasets/#liveness-probe)
    - [Clean up](study-jams/k8s/default/replicasets/#clean-up-1)
  - [5 - Manual rolling update](study-jams/k8s/default/replicasets/#5---manual-rolling-update)
    - [Deploy the initial `ReplicaSet`](study-jams/k8s/default/replicasets/#deploy-the-initial-replicaset)
    - [Update the `ReplicaSet` pod template](study-jams/k8s/default/replicasets/#update-the-replicaset-pod-template)
    - [Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`](study-jams/k8s/default/replicasets/#update-the-replicaset-pod-template-with-the-fixed-readinessprobe)
    - [Clean up the failing versions and the old ones](study-jams/k8s/default/replicasets/#clean-up-the-failing-versions-and-the-old-ones)
