# Storage

Kubernetes provides several mechanisms to manage configuration, sensitive data, and persistent storage for pods.

## Prerequisites

- A running Kubernetes cluster (e.g., [Kind](../00-Kind/README.md))
- `kubectl` configured to communicate with the cluster

## Labs

| Lab | Topic | Description |
|-----|-------|-------------|
| [03.1-ConfigMaps](03.1-ConfigMaps/) | ConfigMaps | Inject configuration as environment variables or mounted files. Live updates without pod restart. |
| [03.2-Secrets](03.2-Secrets/) | Secrets | Store and inject sensitive data (passwords, tokens). Base64 encoding and volume mounting. |
| [03.3-Volumes](03.3-Volumes/) | Persistent Volumes | Data persistence across pod restarts using PersistentVolumeClaims. |
| [03.4-DownwardAPI](03.4-DownwardAPI/) | Downward API | Expose pod metadata (name, namespace, IP, labels, annotations) to containers. |
