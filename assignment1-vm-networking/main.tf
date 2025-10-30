# Assignment 1: Virtual Machines & Networking
# Deploy a secure Linux web server using reusable Terraform modules
# Author: Senior Azure/Terraform Engineer with 5 years Terraform & 9 years Azure experience

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# Data sources for existing resources (if any)
data "azurerm_client_config" "current" {}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Local values for consistent tagging and configuration
locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    Owner         = var.owner
    CostCenter    = var.cost_center
    DeployedBy    = "Terraform"
    DeployedAt    = timestamp()
    Assignment    = "Assignment1-VM-Networking"
  }

  # Network configuration
  network_config = {
    vnet_address_space = [var.vnet_address_space]
    subnets = {
      web = {
        address_prefix = var.web_subnet_cidr
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      }
      management = {
        address_prefix = var.management_subnet_cidr
        service_endpoints = ["Microsoft.Storage"]
      }
    }
  }

  # Security rules for web server
  web_security_rules = {
    "Allow_SSH_Management" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = var.management_source_ip
      destination_address_prefix = "*"
      description              = "Allow SSH from management network"
    }
    "Allow_HTTP_Internet" = {
      priority                   = 1010
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "80"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow HTTP from internet"
    }
    "Allow_HTTPS_Internet" = {
      priority                   = 1020
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "443"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow HTTPS from internet"
    }
    "Deny_All_Inbound" = {
      priority                   = 4000
      direction                 = "Inbound"
      access                    = "Deny"
      protocol                  = "*"
      source_port_range         = "*"
      destination_port_range    = "*"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Deny all other inbound traffic"
    }
  }
}

# Module: Virtual Network and Subnets
module "network" {
  source = "../modules/vnet_subnet"

  vnet_name           = "${var.project_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = local.network_config.vnet_address_space
  subnets             = local.network_config.subnets
  environment         = var.environment

  tags = merge(local.common_tags, {
    Component = "Networking"
  })
}

# Module: Network Security Group for Web Servers
module "web_nsg" {
  source = "../modules/network_security_group"

  nsg_name            = "${var.project_name}-web-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  security_rules      = local.web_security_rules
  subnet_id           = module.network.subnet_ids["web"]
  environment         = var.environment

  tags = merge(local.common_tags, {
    Component = "Security"
    Purpose   = "Web-Server-Protection"
  })
}

# Module: Web Server Virtual Machine
module "web_server" {
  source = "../modules/virtual_machine"

  vm_name             = "${var.project_name}-web-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids["web"]

  # VM Configuration
  vm_size                     = var.vm_size
  admin_username             = var.admin_username
  generate_ssh_key           = var.generate_ssh_key
  admin_ssh_key              = var.admin_ssh_key

  # Network Configuration
  create_public_ip            = true
  public_ip_allocation_method = "Static"
  public_ip_sku              = "Standard"

  # Storage Configuration
  os_disk_storage_account_type = var.os_disk_type
  os_disk_size_gb             = var.os_disk_size_gb
  create_data_disk            = var.create_data_disk
  data_disk_size_gb           = var.data_disk_size_gb
  data_disk_storage_account_type = var.data_disk_type

  # Web Server Configuration
  install_web_server = true
  web_server_type   = var.web_server_type
  
  # Enhanced cloud-init script for assignment requirements
  custom_cloud_init_script = <<-EOF
    # Assignment 1 specific configurations
    - echo "Assignment 1: Secure Linux Web Server" >> /var/log/assignment1.log
    - echo "Deployed at: $(date)" >> /var/log/assignment1.log
    - echo "Web Server Type: ${var.web_server_type}" >> /var/log/assignment1.log
    
    # Configure firewall for web server
    - ufw allow from ${var.management_source_ip} to any port 22
    - ufw allow 80/tcp
    - ufw allow 443/tcp
    - ufw --force enable
    
    # Additional security hardening
    - echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
    - echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    - systemctl restart sshd
    
    # Create assignment completion marker
    - echo "Assignment 1 deployment completed successfully at $(date)" > /tmp/assignment1-complete.txt
  EOF

  # Monitoring and Identity
  identity_type               = "SystemAssigned"
  install_azure_monitor_agent = var.enable_monitoring
  enable_boot_diagnostics     = true
  environment                = var.environment

  tags = merge(local.common_tags, {
    Component   = "Web-Server"
    Application = "NGINX-Web-Server"
    Backup      = "Required"
  })

  depends_on = [
    module.network,
    module.web_nsg
  ]
}

# Additional Network Security Group for Management Subnet (if needed)
module "management_nsg" {
  source = "../modules/network_security_group"

  nsg_name            = "${var.project_name}-mgmt-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  security_rules = {
    "Allow_SSH_Admin" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = var.management_source_ip
      destination_address_prefix = "*"
      description              = "Allow SSH for administration"
    }
    "Deny_All_Other" = {
      priority                   = 2000
      direction                 = "Inbound"
      access                    = "Deny"
      protocol                  = "*"
      source_port_range         = "*"
      destination_port_range    = "*"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Deny all other traffic"
    }
  }

  subnet_id   = module.network.subnet_ids["management"]
  environment = var.environment

  tags = merge(local.common_tags, {
    Component = "Security"
    Purpose   = "Management-Network-Protection"
  })
}

# Output the important information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = module.network.subnet_ids
}

output "web_nsg_id" {
  description = "ID of the web server network security group"
  value       = module.web_nsg.nsg_id
}

output "web_server_public_ip" {
  description = "Public IP address of the web server"
  value       = module.web_server.public_ip_address
}

output "web_server_private_ip" {
  description = "Private IP address of the web server"
  value       = module.web_server.private_ip_address
}

output "web_server_fqdn" {
  description = "FQDN of the web server public IP"
  value       = module.web_server.public_ip_fqdn
}

output "web_server_url" {
  description = "URL to access the web server"
  value       = module.web_server.web_server_url
}

output "ssh_connection_command" {
  description = "SSH command to connect to the web server"
  value       = module.web_server.ssh_connection_command
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key (if generated)"
  value       = module.web_server.ssh_private_key
  sensitive   = true
}

output "vm_id" {
  description = "ID of the web server virtual machine"
  value       = module.web_server.vm_id
}

output "vm_name" {
  description = "Name of the web server virtual machine"  
  value       = module.web_server.vm_name
}

output "network_interface_id" {
  description = "ID of the web server network interface"
  value       = module.web_server.network_interface_id
}

# Assignment completion summary
output "assignment1_summary" {
  description = "Assignment 1 deployment summary"
  value = {
    status                = "completed"
    web_server_deployed   = true
    networking_configured = true
    security_groups_applied = true
    public_ip_assigned    = module.web_server.public_ip_address != null
    web_server_type      = var.web_server_type
    ssh_access_configured = true
    http_access_enabled   = true
    deployment_timestamp  = timestamp()
    modules_used = [
      "vnet_subnet",
      "network_security_group", 
      "virtual_machine"
    ]
  }
}