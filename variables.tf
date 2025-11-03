variable "client_id" {
  description = "Client ID del servicio registrado en Azure AD"
  type        = string
}

variable "client_secret" {
  description = "Client Secret del servicio registrado en Azure AD"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Tenant ID de Azure"
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID de Azure"
  type        = string
}

variable "admin_login" {
  description = "Administrador del servidor SQL"
  type        = string
}

variable "admin_password" {
  description = "Contraseña del administrador del servidor SQL"
  type        = string
  sensitive   = true
}
