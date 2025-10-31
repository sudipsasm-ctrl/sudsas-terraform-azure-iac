# Variables for Virtual Machine Module
# Variable definitions for VM configuration

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,63}[a-zA-Z0-9]$", var.vm_name))
    error_message = "VM name must be 3-64 characters, start and end with alphanumeric, contain only alphanumeric and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where the VM will be deployed"
  type        = string
}

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
    condition     = length(var.admin_username) >= 1 && length(var.admin_username) <= 64
    error_message = "Admin username must be between 1 and 64 characters."
  }
}

variable "admin_ssh_key" {
  description = "SSH public key for admin user authentication"
  type        = string
  default     = null
  validation {
    condition = var.admin_ssh_key == null || can(regex("^ssh-(rsa|ed25519|ecdsa)", var.admin_ssh_key))
    error_message = "SSH key must be in OpenSSH format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)."
  }
}

variable "generate_ssh_key" {
  description = "Whether to generate an SSH key pair automatically"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "ID of the subnet where the VM will be deployed"
  type        = string
}

variable "create_public_ip" {
  description = "Whether to create and assign a public IP address"
  type        = bool
  default     = true
}

variable "public_ip_allocation_method" {
  description = "Allocation method for public IP"
  type        = string
  default     = "Static"
  validation {
    condition     = contains(["Static", "Dynamic"], var.public_ip_allocation_method)
    error_message = "Public IP allocation method must be Static or Dynamic."
  }
}

variable "public_ip_sku" {
  description = "SKU for public IP"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard"], var.public_ip_sku)
    error_message = "Public IP SKU must be Basic or Standard."
  }
}

variable "private_ip_allocation_method" {
  description = "Allocation method for private IP"
  type        = string
  default     = "Dynamic"
  validation {
    condition     = contains(["Dynamic", "Static"], var.private_ip_allocation_method)
    error_message = "Private IP allocation method must be Dynamic or Static."
  }
}

variable "private_ip_address" {
  description = "Static private IP address (used when allocation method is Static)"
  type        = string
  default     = null
}

# OS Configuration
variable "vm_image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "Canonical"
}

variable "vm_image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "0001-com-ubuntu-server-focal"
}

variable "vm_image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "20_04-lts-gen2"
}

variable "vm_image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"
}

# Disk Configuration
variable "os_disk_caching" {
  description = "Caching type for OS disk"
  type        = string
  default     = "ReadWrite"
  validation {
    condition     = contains(["None", "ReadOnly", "ReadWrite"], var.os_disk_caching)
    error_message = "OS disk caching must be None, ReadOnly, or ReadWrite."
  }
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for OS disk"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains([
      "Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"
    ], var.os_disk_storage_account_type)
    error_message = "OS disk storage account type must be a valid Azure disk type."
  }
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = null
  validation {
    condition     = var.os_disk_size_gb == null || (var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095)
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

variable "data_disk_storage_account_type" {
  description = "Storage account type for data disk"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition = contains([
      "Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_ZRS"
    ], var.data_disk_storage_account_type)
    error_message = "Data disk storage account type must be a valid Azure disk type."
  }
}

variable "data_disk_caching" {
  description = "Caching type for data disk"
  type        = string
  default     = "ReadWrite"
  validation {
    condition     = contains(["None", "ReadOnly", "ReadWrite"], var.data_disk_caching)
    error_message = "Data disk caching must be None, ReadOnly, or ReadWrite."
  }
}

# Web Server Configuration
variable "install_web_server" {
  description = "Whether to install and configure a web server"
  type        = bool
  default     = true
}

variable "web_server_type" {
  description = "Type of web server to install (nginx or apache)"
  type        = string
  default     = "nginx"
  validation {
    condition     = contains(["nginx", "apache"], var.web_server_type)
    error_message = "Web server type must be nginx or apache."
  }
}

variable "custom_data" {
  description = "Custom data to pass to the VM (base64 encoded)"
  type        = string
  default     = null
}

variable "custom_cloud_init_script" {
  description = "Custom cloud-init script commands to execute"
  type        = string
  default     = ""
}

# Extensions and Monitoring
variable "use_vm_extension" {
  description = "Whether to use VM extensions for configuration"
  type        = bool
  default     = false
}

variable "custom_script_uri" {
  description = "URI of custom script to run via VM extension"
  type        = string
  default     = null
}

variable "custom_script_command" {
  description = "Command to execute the custom script"
  type        = string
  default     = null
}

variable "install_azure_monitor_agent" {
  description = "Whether to install Azure Monitor Agent"
  type        = bool
  default     = false
}

variable "enable_boot_diagnostics" {
  description = "Whether to enable boot diagnostics"
  type        = bool
  default     = true
}

variable "boot_diagnostics_storage_uri" {
  description = "Storage URI for boot diagnostics (leave null for managed storage)"
  type        = string
  default     = null
}

# Identity Configuration
variable "identity_type" {
  description = "Type of managed identity (SystemAssigned, UserAssigned, or SystemAssigned, UserAssigned)"
  type        = string
  default     = null
  validation {
    condition = var.identity_type == null || contains([
      "SystemAssigned", 
      "UserAssigned", 
      "SystemAssigned, UserAssigned"
    ], var.identity_type)
    error_message = "Identity type must be SystemAssigned, UserAssigned, or SystemAssigned, UserAssigned."
  }
}

variable "identity_ids" {
  description = "List of user assigned identity IDs"
  type        = list(string)
  default     = []
}

# Tagging and Environment
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