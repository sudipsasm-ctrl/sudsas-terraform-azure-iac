# Outputs for Virtual Machine Module
# Output information for dependent resources

output "vm_id" {
  description = "The ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "vm_location" {
  description = "The location of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.location
}

output "vm_size" {
  description = "The size of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.size
}

output "vm_admin_username" {
  description = "The admin username of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}

output "public_ip_address" {
  description = "The public IP address of the virtual machine"
  value       = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].ip_address : null
}

output "public_ip_fqdn" {
  description = "The FQDN of the public IP address"
  value       = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].fqdn : null
}

output "private_ip_address" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "network_interface_id" {
  description = "The ID of the network interface"
  value       = azurerm_network_interface.vm_nic.id
}

output "network_interface_name" {
  description = "The name of the network interface"
  value       = azurerm_network_interface.vm_nic.name
}

output "public_ip_id" {
  description = "The ID of the public IP address"
  value       = var.create_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
}

output "ssh_private_key" {
  description = "The generated SSH private key (if generated)"
  value       = var.generate_ssh_key ? tls_private_key.ssh_key[0].private_key_pem : null
  sensitive   = true
}

output "ssh_public_key" {
  description = "The SSH public key used for the VM"
  value       = var.generate_ssh_key ? tls_private_key.ssh_key[0].public_key_openssh : var.admin_ssh_key
  sensitive   = false
}

output "os_disk_id" {
  description = "The ID of the OS disk"
  value       = azurerm_linux_virtual_machine.vm.os_disk[0].name
}

output "data_disk_id" {
  description = "The ID of the data disk (if created)"
  value       = var.create_data_disk ? azurerm_managed_disk.data_disk[0].id : null
}

# System identity outputs
output "system_assigned_identity_principal_id" {
  description = "The principal ID of the system assigned identity"
  value       = var.identity_type != null && contains(split(",", replace(var.identity_type, " ", "")), "SystemAssigned") ? azurerm_linux_virtual_machine.vm.identity[0].principal_id : null
}

output "system_assigned_identity_tenant_id" {
  description = "The tenant ID of the system assigned identity"
  value       = var.identity_type != null && contains(split(",", replace(var.identity_type, " ", "")), "SystemAssigned") ? azurerm_linux_virtual_machine.vm.identity[0].tenant_id : null
}

# Web server information
output "web_server_type" {
  description = "The type of web server installed"
  value       = var.install_web_server ? var.web_server_type : "none"
}

output "web_server_url" {
  description = "The URL to access the web server"
  value       = var.create_public_ip && var.install_web_server ? "http://${azurerm_public_ip.vm_public_ip[0].ip_address}" : null
}

# Connection information
output "ssh_connection_command" {
  description = "SSH connection command for the VM"
  value       = var.create_public_ip ? "ssh ${var.admin_username}@${azurerm_public_ip.vm_public_ip[0].ip_address}" : "ssh ${var.admin_username}@${azurerm_network_interface.vm_nic.private_ip_address}"
}

# Resource group information
output "resource_group_name" {
  description = "The name of the resource group"
  value       = var.resource_group_name
}

# Subnet information
output "subnet_id" {
  description = "The ID of the subnet"
  value       = var.subnet_id
}

# VM state and health
output "vm_power_state" {
  description = "The power state of the VM"
  value       = azurerm_linux_virtual_machine.vm.power_state
}

# Extension information
output "azure_monitor_agent_installed" {
  description = "Whether Azure Monitor Agent is installed"
  value       = var.install_azure_monitor_agent
}

output "custom_extension_installed" {
  description = "Whether custom VM extension is installed"
  value       = var.use_vm_extension && var.custom_script_uri != null
}

# Tags
output "tags" {
  description = "Tags applied to the VM"
  value       = azurerm_linux_virtual_machine.vm.tags
}

# Managed disk information
output "managed_disks" {
  description = "Information about managed disks attached to the VM"
  value = {
    os_disk = {
      name                 = azurerm_linux_virtual_machine.vm.os_disk[0].name
      caching             = azurerm_linux_virtual_machine.vm.os_disk[0].caching
      storage_account_type = azurerm_linux_virtual_machine.vm.os_disk[0].storage_account_type
      disk_size_gb        = azurerm_linux_virtual_machine.vm.os_disk[0].disk_size_gb
    }
    data_disk = var.create_data_disk ? {
      name                 = azurerm_managed_disk.data_disk[0].name
      storage_account_type = azurerm_managed_disk.data_disk[0].storage_account_type
      disk_size_gb        = azurerm_managed_disk.data_disk[0].disk_size_gb
    } : null
  }
}