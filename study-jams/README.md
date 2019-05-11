## This is a work in progress!

This folder contains all the resources used during the Cloud Native Barcelona Kubernetes Study Jams.

- [Cloud Native Barcelona - April 26th](https://www.meetup.com/Cloud-Native-Barcelona/events/260422493/)
- [Cloud Native Barcelona - May 9th](https://www.meetup.com/Cloud-Native-Barcelona/events/260756033/)

## Content


- [`ReplicaSets`](k8s/default/replicasets/#replicasets)
  - [Introduction](k8s/default/replicasets/#introduction)
    - [Learn more](k8s/default/replicasets/#learn-more)
    - [Some notes](k8s/default/replicasets/#some-notes)
  - [1 - Create a `ReplicaSet`](k8s/default/replicasets/#1---create-a-replicaset)
  - [2 - Scaling `ReplicaSets`](k8s/default/replicasets/#2---scaling-replicasets)
    - [Double the numbers of replicas with `kubectl scale`](k8s/default/replicasets/#double-the-numbers-of-replicas-with-kubectl-scale)
    - [Scale back to 1 replica](k8s/default/replicasets/#scale-back-to-1-replica)
    - [Update the `ReplicaSet` with the yaml definition](k8s/default/replicasets/#update-the-replicaset-with-the-yaml-definition)
    - [Scale to 50 replicas](k8s/default/replicasets/#scale-to-50-replicas)
    - [Scale down back to 5 replicas](k8s/default/replicasets/#scale-down-back-to-5-replicas)
  - [3 - Selectors and Pods](k8s/default/replicasets/#3---selectors-and-pods)
    - [Deploy some **blue** pods](k8s/default/replicasets/#deploy-some-blue-pods)
    - [Deploy a **blue** `ReplicaSet`](k8s/default/replicasets/#deploy-a-blue-replicaset)
    - [Run a _red_ pod](k8s/default/replicasets/#run-a-red-pod)
    - [`ReplicaSet` for non-colored pods only](k8s/default/replicasets/#replicaset-for-non-colored-pods-only)
    - [Let's acquire those fancy orange `pods`](k8s/default/replicasets/#lets-acquire-those-fancy-orange-pods)
    - [Remove a pod from the orange replicaset](k8s/default/replicasets/#remove-a-pod-from-the-orange-replicaset)
    - [Clean up](k8s/default/replicasets/#clean-up)
  - [4 - Container probes](k8s/default/replicasets/#4---container-probes)
    - [Readiness probe](k8s/default/replicasets/#readiness-probe)
    - [Liveness probe](k8s/default/replicasets/#liveness-probe)
    - [Clean up](k8s/default/replicasets/#clean-up-1)
  - [5 - Manual rolling update](k8s/default/replicasets/#5---manual-rolling-update)
    - [Deploy the initial `ReplicaSet`](k8s/default/replicasets/#deploy-the-initial-replicaset)
    - [Update the `ReplicaSet` pod template](k8s/default/replicasets/#update-the-replicaset-pod-template)
    - [Update the `ReplicaSet` `Pod` template with the fixed `ReadinessProbe`](k8s/default/replicasets/#update-the-replicaset-pod-template-with-the-fixed-readinessprobe)
    - [Clean up the failing versions and the old ones](k8s/default/replicasets/#clean-up-the-failing-versions-and-the-old-ones)
