variable "region" {
  description = "Región autorizada por el laboratorio de AWS Academy."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.region))
    error_message = "Indica una región AWS válida y autorizada por tu laboratorio."
  }
}

variable "account_id" {
  description = "ID de 12 cifras de la cuenta esperada; proveedor AWS y precondición del bucket rechazan otra cuenta."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id debe contener exactamente 12 cifras."
  }
}

variable "lab_id" {
  description = "El mismo identificador propio usado en bootstrap, de 3 a 20 caracteres."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.lab_id))
    error_message = "Usa 3–20 letras minúsculas, cifras o guiones; empieza y termina con letra o cifra."
  }
}

variable "bucket_name" {
  description = "Nombre exacto opcional; null genera un nombre con cuenta, lab_id y sufijo aleatorio persistente."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.|\\.-|-\\.", var.bucket_name)) &&
      !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bucket_name))
    )
    error_message = "Usa null o un nombre S3 de 3–63 caracteres, minúsculas/cifras/puntos/guiones, sin puntos consecutivos, puntos junto a guiones ni formato IPv4; empieza y termina con letra o cifra."
  }
}

variable "demo_tag" {
  description = "Etiqueta del ejercicio para practicar cambios declarativos y drift sin tocar el backend."
  type        = string
  default     = "initial"
}
