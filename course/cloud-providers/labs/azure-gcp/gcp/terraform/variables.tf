variable "project_id" {
  description = "ID del proyecto docente existente, no número ni nombre visible."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Indica un project ID GCP válido (6–30 caracteres)."
  }
}
variable "region" {
  description = "Región docente explícita, por ejemplo europe-west1."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Indica una región GCP válida."
  }
}
variable "zone" {
  description = "Zona explícita perteneciente a region, por ejemplo europe-west1-b."
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "Indica una zona GCP válida."
  }
}
variable "lab_id" {
  description = "Identificador propio único, igual al usado en Azure."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}[a-z0-9]$", var.lab_id))
    error_message = "lab_id: 3–12 caracteres minúsculos/dígitos/guiones, empezando por letra."
  }
}
variable "http_client_cidr" {
  description = "IPv4 de salida docente /24–/32 explícita; preferir /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.http_client_cidr)) && can(regex("/(2[4-9]|3[0-2])$", var.http_client_cidr))
    error_message = "Indica un CIDR IPv4 restringido /24–/32; nunca 0.0.0.0/0."
  }
}
variable "machine_type" {
  description = "Máquina pequeña previamente comprobada en región/zona."
  type        = string
  default     = "e2-micro"
  validation {
    condition     = contains(["e2-micro", "e2-small"], var.machine_type)
    error_message = "El ejercicio admite e2-micro o e2-small; no presupone gratuidad."
  }
}
variable "bucket_name" {
  description = "Nombre nuevo y globalmente disponible; null añade un sufijo aleatorio persistido en estado."
  type        = string
  default     = null
  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$|^goog|google|g00gle", var.bucket_name))
    )
    error_message = "Usa null o 3–63 minúsculas/dígitos/guiones/guiones bajos, extremos alfanuméricos y sin nombres reservados de Google."
  }
}
