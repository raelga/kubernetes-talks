variable "subscription_id" {
  description = "Approved Azure subscription ID; provide with TF_VAR_subscription_id."
  type        = string
}

variable "location" {
  description = "Approved Azure region for the backend resources."
  type        = string
  default     = "westeurope"
}
