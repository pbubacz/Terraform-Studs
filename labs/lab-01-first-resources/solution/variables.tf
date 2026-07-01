variable "prefix" {
  type        = string
  description = "Naming prefix, e.g. tfcourse-ab (your initials)."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.prefix))
    error_message = "prefix must contain only lowercase letters, digits and dashes."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "polandcentral"
}

variable "owner" {
  type        = string
  description = "Owner tag value (email)."
}
