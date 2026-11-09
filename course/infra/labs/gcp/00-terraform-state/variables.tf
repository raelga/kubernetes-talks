variable "project_id" {
  description = "Approved Google Cloud project ID."
  type        = string
  default     = null
}

variable "location" {
  description = "Approved Cloud Storage bucket location."
  type        = string
  default     = "US-WEST1"
}
