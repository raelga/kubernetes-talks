# EC2 lab guide

Use the [lab README](README.md) for shell inputs, Terraform commands, the private EC2/ALB security model, optional ACM HTTPS and cleanup. The ALB keeps public IPv4 HTTP/HTTPS access; the numbered security-group step explains why private EC2 accepts HTTP only from the ALB security group, not from client IP ranges. The deployable configuration and automatic launch installer are in [`infra/`](infra/); Apache serves [`app/`](app/). Installation requires no manual instance commands. Session Manager and bootstrap logs are optional troubleshooting tools.
