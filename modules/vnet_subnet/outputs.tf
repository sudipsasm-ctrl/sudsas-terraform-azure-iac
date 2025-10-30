# Outputs for Virtual Network and Subnet Module
# Provides comprehensive output information for dependent modules

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_location" {
  description = "The location of the virtual network"
  value       = azurerm_virtual_network.vnet.location
}

output "vnet_address_space" {
  description = "The address space of the virtual network"
  value       = azurerm_virtual_network.vnet.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    for k, v in azurerm_subnet.subnet : k => v.id
  }
}

output "subnet_names" {
  description = "Map of subnet names to their full names"
  value = {
    for k, v in azurerm_subnet.subnet : k => v.name
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to their address prefixes"
  value = {
    for k, v in azurerm_subnet.subnet : k => v.address_prefixes[0]
  }
}

output "route_table_ids" {
  description = "Map of route table names to their IDs (if created)"
  value = {
    for k, v in azurerm_route_table.rt : k => v.id
  }
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = var.resource_group_name
}

# Useful for security group associations
output "subnet_cidr_blocks" {
  description = "Map of subnet names to their CIDR blocks for NSG rules"
  value = {
    for k, v in azurerm_subnet.subnet : k => v.address_prefixes[0]
  }
}

# Output for network peering or other advanced networking scenarios
output "vnet_guid" {
  description = "The GUID of the virtual network"
  value       = azurerm_virtual_network.vnet.guid
}

output "dns_servers" {
  description = "DNS servers configured for the VNet"
  value       = azurerm_virtual_network.vnet.dns_servers
}