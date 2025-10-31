# Variables for Network Security Group Module
# Variable definitions for NSG configuration

variable "nsg_name" {
  description = "Name of the network security group"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]{1,78}[a-zA-Z0-9]$", var.nsg_name))
    error_message = "NSG name must be 3-80 characters, start and end with alphanumeric."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where the NSG will be deployed"
  type        = string
}

variable "security_rules" {
  description = "Map of security rules to create"
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range           = optional(string)
    source_port_ranges          = optional(list(string))
    destination_port_range      = optional(string)
    destination_port_ranges     = optional(list(string))
    source_address_prefix       = optional(string)
    source_address_prefixes     = optional(list(string))
    destination_address_prefix  = optional(string)
    destination_address_prefixes = optional(list(string))
    description                 = optional(string)
  }))
  default = {}
  
  validation {
    condition = alltrue([
      for rule_name, rule in var.security_rules :
      rule.priority >= 100 && rule.priority <= 4096
    ])
    error_message = "Security rule priorities must be between 100 and 4096."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in var.security_rules :
      contains(["Inbound", "Outbound"], rule.direction)
    ])
    error_message = "Security rule direction must be either 'Inbound' or 'Outbound'."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in var.security_rules :
      contains(["Allow", "Deny"], rule.access)
    ])
    error_message = "Security rule access must be either 'Allow' or 'Deny'."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in var.security_rules :
      contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], rule.protocol)
    ])
    error_message = "Security rule protocol must be Tcp, Udp, Icmp, Esp, Ah, or *."
  }
}

variable "create_common_web_rules" {
  description = "Whether to create common web server security rules (SSH, HTTP, HTTPS)"
  type        = bool
  default     = false
}

variable "ssh_source_address_prefix" {
  description = "Source address prefix for SSH access (used with common web rules)"
  type        = string
  default     = "*"
  validation {
    condition = can(cidrhost(var.ssh_source_address_prefix, 0)) || var.ssh_source_address_prefix == "*" || var.ssh_source_address_prefix == "Internet" || var.ssh_source_address_prefix == "VirtualNetwork"
    error_message = "SSH source address prefix must be a valid CIDR block, *, Internet, or VirtualNetwork."
  }
}

variable "subnet_id" {
  description = "ID of the subnet to associate with the NSG"
  type        = string
  default     = null
}

variable "network_interface_ids" {
  description = "Set of network interface IDs to associate with the NSG"
  type        = set(string)
  default     = []
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

# Predefined rule templates for common scenarios
variable "enable_rdp" {
  description = "Enable RDP access (port 3389)"
  type        = bool
  default     = false
}

variable "rdp_source_address_prefix" {
  description = "Source address prefix for RDP access"
  type        = string
  default     = "*"
}

variable "enable_winrm" {
  description = "Enable WinRM access (ports 5985, 5986)"
  type        = bool
  default     = false
}

variable "custom_inbound_ports" {
  description = "List of custom inbound ports to allow"
  type        = list(string)
  default     = []
}

variable "custom_outbound_ports" {
  description = "List of custom outbound ports to allow"
  type        = list(string)
  default     = []
}