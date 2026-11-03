variable "subscription_id" {
  description = "Suscripción docente explícita; no se selecciona una suscripción por defecto."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "Indica el UUID de la suscripción docente."
  }
}
variable "location" {
  description = "Región previamente autorizada con cuota, por ejemplo westeurope."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Utiliza el nombre de región Azure sin espacios."
  }
}
variable "lab_id" {
  description = "Identificador propio y único por docente/grupo, 3–12 caracteres."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}[a-z0-9]$", var.lab_id))
    error_message = "lab_id: 3–12 caracteres ASCII minúsculos/dígitos/guiones, empezando por letra."
  }
}
variable "http_client_cidr" {
  description = "IPv4 de salida docente explícita /24–/32; preferir una única /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.http_client_cidr)) && can(regex("/(2[4-9]|3[0-2])$", var.http_client_cidr))
    error_message = "Indica un CIDR IPv4 restringido /24–/32; nunca 0.0.0.0/0."
  }
}
variable "ssh_public_key_path" {
  description = "Ruta local a clave PÚBLICA SSH ya existente. No abre el puerto 22."
  type        = string
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) ", trimspace(file(pathexpand(var.ssh_public_key_path)))))
    error_message = "La ruta debe contener una clave PÚBLICA SSH RSA/ed25519 existente, nunca la privada."
  }
}
variable "vm_size" {
  description = "SKU pequeño con cuota previamente comprobada por el docente."
  type        = string
  default     = "Standard_B1s"
  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2s"], var.vm_size)
    error_message = "El ejercicio admite únicamente Standard_B1s, B1ms o B2s; comprobar disponibilidad y precio."
  }
}
variable "storage_account_name" {
  description = "Nombre nuevo y globalmente disponible; null añade un sufijo aleatorio persistido en estado."
  type        = string
  default     = null
  validation {
    condition     = var.storage_account_name == null ? true : can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Usa null o 3–24 letras minúsculas y dígitos."
  }
}
