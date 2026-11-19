# Container labs

Explore Linux namespaces/cgroups, Docker and Docker Compose. Check each lab's prerequisites before starting.

- [Namespaces and cgroups](labs/01-Namespaces-and-CGroups/README.md)
  - [Cgroups v2: memory limits](labs/01-Namespaces-and-CGroups/cgroups-v2.md)
- [Docker examples](labs/02-Docker/)
  - [Users and PIDs: host vs container](labs/02-Docker/02.3-isolation/README.md)
  - [Push and pull with Amazon ECR](labs/02-Docker/02.6-ECR/README.md)
- [Docker Compose examples](labs/03-Docker-Compose/)
  - [Two Python services with Compose](labs/03-Docker-Compose/03.3-python/README.md)

Use a suitable Linux machine or provision a dedicated instance with the [Terraform configurations](../terraform/): [restricted-account EC2](../terraform/aws-academy-ec2-instance/), [EC2](../terraform/ec2-instance/) or [EC2 Spot](../terraform/ec2-spot-instance/). Check permissions, instance availability and costs before deploying; remove only your own resources afterward.
