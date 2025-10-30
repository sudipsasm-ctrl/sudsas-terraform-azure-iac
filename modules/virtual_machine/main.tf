# Virtual Machine Module
# This module creates Azure VMs with cloud-init support and web server installation
# Author: Senior Azure/Terraform Engineer
# Version: 1.0.0

terraform {
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

# Generate SSH key pair if not provided
resource "tls_private_key" "ssh_key" {
  count     = var.generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create public IP
resource "azurerm_public_ip" "vm_public_ip" {
  count               = var.create_public_ip ? 1 : 0
  name                = "${var.vm_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = var.public_ip_allocation_method
  sku                = var.public_ip_sku

  tags = merge(var.tags, {
    Module    = "virtual_machine"
    Component = "public_ip"
  })
}

# Create Network Interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_allocation_method
    private_ip_address           = var.private_ip_address
    public_ip_address_id         = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = merge(var.tags, {
    Module    = "virtual_machine"
    Component = "network_interface"
  })
}

# Cloud-init configuration for web server installation
locals {
  cloud_init_config = var.install_web_server ? base64encode(templatefile("${path.module}/cloud-init.yaml", {
    web_server_type = var.web_server_type
    custom_script   = var.custom_cloud_init_script
  })) : var.custom_data
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication and use SSH keys
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.generate_ssh_key ? tls_private_key.ssh_key[0].public_key_openssh : var.admin_ssh_key
  }

  os_disk {
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb        = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  custom_data = local.cloud_init_config

  # Optional identity configuration
  dynamic "identity" {
    for_each = var.identity_type != null ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = var.identity_ids
    }
  }

  # Boot diagnostics
  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = var.boot_diagnostics_storage_uri
    }
  }

  tags = merge(var.tags, {
    Module      = "virtual_machine"
    Environment = var.environment
    WebServer   = var.install_web_server ? var.web_server_type : "none"
  })

  lifecycle {
    ignore_changes = [
      custom_data,
    ]
  }
}

# Optional managed disk for additional storage
resource "azurerm_managed_disk" "data_disk" {
  count                = var.create_data_disk ? 1 : 0
  name                 = "${var.vm_name}-data-disk"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb

  tags = merge(var.tags, {
    Module    = "virtual_machine"
    Component = "data_disk"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  count              = var.create_data_disk ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data_disk[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = 0
  caching            = var.data_disk_caching
}

# VM Extension for additional configuration (alternative to cloud-init)
resource "azurerm_virtual_machine_extension" "custom_script" {
  count                = var.use_vm_extension && var.custom_script_uri != null ? 1 : 0
  name                 = "${var.vm_name}-custom-script"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    fileUris = [var.custom_script_uri]
  })

  protected_settings = jsonencode({
    commandToExecute = var.custom_script_command
  })

  tags = merge(var.tags, {
    Module    = "virtual_machine"
    Component = "extension"
  })
}

# Azure Monitor Agent extension (for monitoring and patch management)
resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  count                      = var.install_azure_monitor_agent ? 1 : 0
  name                       = "${var.vm_name}-ama"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = merge(var.tags, {
    Module    = "virtual_machine"
    Component = "monitor_agent"
  })
}