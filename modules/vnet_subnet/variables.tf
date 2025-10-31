# Variables for Virtual Network and Subnet Module
# Variable definitions with validation

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,78}[a-zA-Z0-9]$", var.vnet_name))
    error_message = "VNet name must be 3-80 characters, start and end with alphanumeric, contain only alphanumeric and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US",
      "South Central US", "West Central US", "North Central US", "Canada Central",
      "Canada East", "Brazil South", "UK South", "UK West", "West Europe",
      "North Europe", "France Central", "Germany West Central", "Switzerland North",
      "Norway East", "Sweden Central", "Australia East", "Australia Southeast",
      "Southeast Asia", "East Asia", "Japan East", "Japan West", "Korea Central",
      "Korea South", "South India", "Central India", "West India", "UAE North"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
  validation {
    condition = alltrue([
      for addr in var.address_space : can(cidrhost(addr, 0))
    ])
    error_message = "Address space must contain valid CIDR notation."
  }
}

variable "subnets" {
  description = "Map of subnets to create"
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(list(string))
    create_route_table = optional(bool, false)
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }))
  
  validation {
    condition = alltrue([
      for subnet_name, subnet_config in var.subnets :
      can(cidrhost(subnet_config.address_prefix, 0))
    ])
    error_message = "All subnet address prefixes must be valid CIDR notation."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection plan"
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "List of DNS servers for the VNet"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for dns in var.dns_servers : can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", dns))
    ])
    error_message = "DNS servers must be valid IPv4 addresses."
  }
}