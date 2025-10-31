# Variables for Assignment 1: Virtual Machines & Networking
# Configuration variables for deploying secure Linux web server

# Basic Configuration
variable "resource_group_name" {
  description = "Name of the resource group for Assignment 1"
  type        = string
  default     = "rg-assignment1-web-server"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_().]{1,88}[a-zA-Z0-9()]$", var.resource_group_name))
    error_message = "Resource group name must be valid Azure resource group name."
  }
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "East US"
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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "assignment1"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 3-22 characters, lowercase, start with letter, contain only letters, numbers, and hyphens."
  }
}

# Tagging Variables
variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Azure-Terraform-Engineer"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Engineering"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.1.0.0/16"
  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
}

variable "web_subnet_cidr" {
  description = "CIDR block for the web server subnet"
  type        = string
  default     = "10.1.1.0/24"
  validation {
    condition     = can(cidrhost(var.web_subnet_cidr, 0))
    error_message = "Web subnet CIDR must be a valid CIDR block."
  }
}

variable "management_subnet_cidr" {
  description = "CIDR block for the management subnet"
  type        = string
  default     = "10.1.100.0/24"
  validation {
    condition     = can(cidrhost(var.management_subnet_cidr, 0))
    error_message = "Management subnet CIDR must be a valid CIDR block."
  }
}

variable "management_source_ip" {
  description = "Source IP or CIDR for management access (SSH)"
  type        = string
  default     = "*"
  validation {
    condition = can(cidrhost(var.management_source_ip, 0)) || var.management_source_ip == "*" || var.management_source_ip == "Internet" || var.management_source_ip == "VirtualNetwork"
    error_message = "Management source IP must be a valid CIDR block, *, Internet, or VirtualNetwork."
  }
}

# Virtual Machine Configuration
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
  validation {
    condition = contains([
      "Standard_B1ls", "Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_B2ms", "Standard_B4ms",
      "Standard_D2s_v3", "Standard_D4s_v3", "Standard_D8s_v3", "Standard_D16s_v3",
      "Standard_E2s_v3", "Standard_E4s_v3", "Standard_E8s_v3", "Standard_E16s_v3",
      "Standard_F2s_v2", "Standard_F4s_v2", "Standard_F8s_v2", "Standard_F16s_v2"
    ], var.vm_size)
    error_message = "VM size must be a valid Azure VM size."
  }
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureuser"
  validation {
    condition     = length(var.admin_username) >= 1 && length(var.admin_username) <= 64 && !contains(["admin", "administrator", "root", "guest"], lower(var.admin_username))
    error_message = "Admin username must be 1-64 characters and not be admin, administrator, root, or guest."
  }
}

variable "generate_ssh_key" {
  description = "Whether to generate an SSH key pair automatically"
  type        = bool
  default     = true
}

variable "admin_ssh_key" {
  description = "SSH public key for admin user (required if generate_ssh_key is false)"
  type        = string
  default     = null
  validation {
    condition = var.admin_ssh_key == null || can(regex("^ssh-(rsa|ed25519|ecdsa)", var.admin_ssh_key))
    error_message = "SSH key must be in OpenSSH format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)."
  }
}

# Storage Configuration
variable "os_disk_type" {
  description = "Storage account type for OS disk"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains([
      "Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"
    ], var.os_disk_type)
    error_message = "OS disk type must be a valid Azure disk type."
  }
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 30
  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "OS disk size must be between 30 and 4095 GB."
  }
}

variable "create_data_disk" {
  description = "Whether to create and attach a data disk"
  type        = bool
  default     = false
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 128
  validation {
    condition     = var.data_disk_size_gb >= 1 && var.data_disk_size_gb <= 32767
    error_message = "Data disk size must be between 1 and 32767 GB."
  }
}

variable "data_disk_type" {
  description = "Storage account type for data disk"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains([
      "Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"
    ], var.data_disk_type)
    error_message = "Data disk type must be a valid Azure disk type."
  }
}

# Web Server Configuration
variable "web_server_type" {
  description = "Type of web server to install (nginx or apache)"
  type        = string
  default     = "nginx"
  validation {
    condition     = contains(["nginx", "apache"], var.web_server_type)
    error_message = "Web server type must be nginx or apache."
  }
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable Azure Monitor Agent"
  type        = bool
  default     = true
}

# Security Configuration
variable "enable_ddos_protection" {
  description = "Whether to enable DDoS protection for the VNet"
  type        = bool
  default     = false
}

variable "enable_network_watcher" {
  description = "Whether to enable Network Watcher"
  type        = bool
  default     = false
}

# Configuration
variable "custom_script_uri" {
  description = "URI of custom script to run after VM deployment"
  type        = string
  default     = null
}

variable "timezone" {
  description = "Timezone for the virtual machine"
  type        = string
  default     = "UTC"
}

# Backup and Recovery
variable "enable_backup" {
  description = "Whether to enable Azure Backup for the VM"
  type        = bool
  default     = false
}

variable "backup_policy_name" {
  description = "Name of the backup policy to use"
  type        = string
  default     = "DefaultPolicy"
}

# High Availability
variable "availability_zone" {
  description = "Availability zone for the VM (1, 2, or 3)"
  type        = string
  default     = null
  validation {
    condition     = var.availability_zone == null || contains(["1", "2", "3"], var.availability_zone)
    error_message = "Availability zone must be 1, 2, or 3."
  }
}