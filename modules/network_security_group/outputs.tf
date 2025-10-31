# Outputs for Network Security Group Module
# Output information for dependent resources

output "nsg_id" {
  description = "The ID of the network security group"
  value       = azurerm_network_security_group.nsg.id
}

output "nsg_name" {
  description = "The name of the network security group"
  value       = azurerm_network_security_group.nsg.name
}

output "nsg_location" {
  description = "The location of the network security group"
  value       = azurerm_network_security_group.nsg.location
}

output "nsg_resource_group_name" {
  description = "The resource group name of the network security group"
  value       = azurerm_network_security_group.nsg.resource_group_name
}

output "security_rule_names" {
  description = "List of security rule names created"
  value       = keys(local.all_rules)
}

output "security_rules" {
  description = "Map of all security rules created"
  value = {
    for rule_name, rule in azurerm_network_security_rule.all_rules :
    rule_name => {
      priority                   = rule.priority
      direction                 = rule.direction
      access                    = rule.access
      protocol                  = rule.protocol
      source_port_range         = rule.source_port_range
      destination_port_range    = rule.destination_port_range
      source_address_prefix     = rule.source_address_prefix
      destination_address_prefix = rule.destination_address_prefix
    }
  }
}

output "subnet_association_id" {
  description = "The ID of the subnet association (if created)"
  value       = length(azurerm_subnet_network_security_group_association.subnet_association) > 0 ? azurerm_subnet_network_security_group_association.subnet_association[0].id : null
}

output "nic_association_ids" {
  description = "Map of network interface association IDs"
  value = {
    for k, v in azurerm_network_interface_security_group_association.nic_association :
    k => v.id
  }
}

# Useful for troubleshooting and auditing
output "inbound_rules" {
  description = "List of inbound security rules"
  value = [
    for rule_name, rule in local.all_rules :
    {
      name     = rule_name
      priority = rule.priority
      access   = rule.access
      protocol = rule.protocol
      port     = lookup(rule, "destination_port_range", "multiple")
    }
    if rule.direction == "Inbound"
  ]
}

output "outbound_rules" {
  description = "List of outbound security rules"
  value = [
    for rule_name, rule in local.all_rules :
    {
      name     = rule_name
      priority = rule.priority
      access   = rule.access
      protocol = rule.protocol
      port     = lookup(rule, "destination_port_range", "multiple")
    }
    if rule.direction == "Outbound"
  ]
}

output "allowed_inbound_ports" {
  description = "List of allowed inbound ports"
  value = [
    for rule_name, rule in local.all_rules :
    lookup(rule, "destination_port_range", "multiple")
    if rule.direction == "Inbound" && rule.access == "Allow" && lookup(rule, "destination_port_range", null) != null
  ]
}

output "tags" {
  description = "Tags applied to the NSG"
  value       = azurerm_network_security_group.nsg.tags
}