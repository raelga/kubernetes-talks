# Kubernetes Clouds

The main subject of this talk is viewing the differences between each managed kubernetes solution offered by AWS, Azure and GCP.

On the labs, the objective is create several kubernetes clusters all over the world using each provider managed (or not) solution and then deploy the same application using the common interface provided by Kubernetes.

## Managed Kubernetes Breakdown Slides

Overview of the managed k8s solutions from GCP, AWS and Azure.

Live slides are available at:

https://talks.godoc.org/github.com/raelga/kubernetes-talks/clouds/kubernetes-clouds.slide

Plain text slides in [kubernetes-clouds.slide](kubernetes-clouds.slide).

## Kubernetes Clouds Labs

In the labs, you will found a step by step guide on how to deploy a kubernetes cluster on each cloud provider:

- [Amazon Web services](labs/aws/#deploy-kubernetes-in-aws)
  - [AWS managed Kubernetes with EKS](labs/aws/#managed-kubernetes-with-eks)
  - [AWS managed Kubernetes with EKS using eksctl](labs/aws/#amazon-web-services---eksctl-alpha)
  - [AWS non-managed on EC2 with Kops](labs/aws/#amazon-web-services---kops)
- [Google Cloud Platform](labs/gcp/#deploy-kubernetes-in-google-cloud-platform)
  - [GCP managed Kubernetes with GKE](labs/gcp#managed-kubernetes-with-google-kubernetes-engine-gke)
- [Azure](labs/azure/#deploy-kubernetes-in-microsoft-azure)
  - [Azure managed Kubernetes with AKS](labs/azure/#managed-kubernetes-with-azure-kubernetes-service-aks)