variable "prefix" {
  type        = string
  description = "Naming prefix, e.g. tfcourse-ab."
  default     = "tfcourse-ab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.prefix))
    error_message = "prefix must contain only lowercase letters, digits and dashes."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "polandcentral"
}

variable "owner" {
  type        = string
  description = "Owner tag value."
  default     = "student@example.com"
}

variable "address_space" {
  type        = string
  description = "VNet address space in CIDR notation."
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.address_space))
    error_message = "address_space must be a valid CIDR block, for example 10.42.0.0/16."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged into the default tag set."
  default     = {}
}

variable "subnets" {
  description = "Subnet definitions keyed by stable subnet name."
  type = map(object({
    index             = number
    newbits           = number
    service_endpoints = optional(list(string), [])
    security_rules = optional(map(object({
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
    })), {})
  }))

  default = {
    web = {
      index             = 1
      newbits           = 8
      service_endpoints = ["Microsoft.Storage"]
      security_rules = {
        allow_http = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "Internet"
          destination_address_prefix = "*"
        }
      }
    }
    app = {
      index   = 2
      newbits = 8
    }
    db = {
      index   = 3
      newbits = 8
      security_rules = {
        allow_sql_from_vnet = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "1433"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        }
      }
    }
  }

  validation {
    condition = alltrue([
      for subnet in values(var.subnets) : subnet.index >= 0 && subnet.newbits >= 1 && subnet.newbits <= 16
    ])
    error_message = "Each subnet must use a non-negative index and newbits between 1 and 16."
  }

  validation {
    condition = alltrue(flatten([
      for subnet in values(var.subnets) : [
        for rule in values(subnet.security_rules) : rule.priority >= 100 && rule.priority <= 4096
      ]
    ]))
    error_message = "NSG rule priorities must be between 100 and 4096."
  }
}