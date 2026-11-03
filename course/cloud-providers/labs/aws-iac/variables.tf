variable "aws_region" {
  description = "Región permitida por el laboratorio Academy asignado."
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Indica una región AWS válida y autorizada por el docente."
  }
}

variable "lab_id" {
  description = "Identificador propio y único; no reutilizar el de otro alumno."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.lab_id))
    error_message = "Usa 3–20 caracteres: letra inicial, minúsculas, números o guiones."
  }
}

variable "client_cidr" {
  description = "IPv4 pública del cliente /32; único origen autorizado para HTTP."
  type        = string
  validation {
    condition = can(cidrnetmask(var.client_cidr)) && can(regex("/32$", var.client_cidr)) && !contains(
      ["0.0.0.0/32", "255.255.255.255/32"], var.client_cidr
    )
    error_message = "Introduce tu IPv4 pública como x.x.x.x/32; no se admiten redes amplias ni 0.0.0.0."
  }
}

variable "instance_type" {
  description = "Tipo x86_64 permitido por Academy; confirmar permiso y cuota antes de apply."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3a.micro", "t3a.small"], var.instance_type)
    error_message = "Selecciona un tipo pequeño x86_64 de la lista y confirma que Academy lo permite."
  }
}

variable "ami_id" {
  description = "AMI Ubuntu 24.04 x86_64 permitida en la región; null busca la oficial de Canonical."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.ami_id == null ? true : can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id debe ser null o un identificador AMI; no una clave ni un nombre."
  }
}

variable "message" {
  description = "Mensaje público de demostración; nunca introducir secretos."
  type        = string
  default     = "Hola desde AWS y UPC"
  validation {
    condition     = length(var.message) >= 1 && length(var.message) <= 120
    error_message = "El mensaje público debe tener entre 1 y 120 caracteres."
  }
}

variable "bucket_name" {
  description = "Nombre S3 nuevo y globalmente disponible; null genera un nombre con sufijo aleatorio persistido en estado."
  type        = string
  default     = null
  validation {
    condition = var.bucket_name == null ? true : (
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("^(xn--|sthree-|amzn-s3-demo-)|(-s3alias|--ol-s3|\\.mrap|--x-s3|--table-s3)$", var.bucket_name))
    )
    error_message = "Usa null o un nombre S3 de 3–63 minúsculas/dígitos/guiones, con extremos alfanuméricos y sin prefijos/sufijos reservados."
  }
}
