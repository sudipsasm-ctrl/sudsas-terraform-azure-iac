# Network Security Group Module
# This module creates NSGs with configurable security rules for Azure networking
# Author: Senior Azure/Terraform Engineer
# Version: 1.0.0

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Create the Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Module      = "network_security_group"
    Environment = var.environment
  })
}

# Create security rules dynamically
resource "azurerm_network_security_rule" "rules" {
  for_each = var.security_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range          = lookup(each.value, "source_port_range", null)
  source_port_ranges         = lookup(each.value, "source_port_ranges", null)
  destination_port_range     = lookup(each.value, "destination_port_range", null)
  destination_port_ranges    = lookup(each.value, "destination_port_ranges", null)
  source_address_prefix      = lookup(each.value, "source_address_prefix", null)
  source_address_prefixes    = lookup(each.value, "source_address_prefixes", null)
  destination_address_prefix = lookup(each.value, "destination_address_prefix", null)
  destination_address_prefixes = lookup(each.value, "destination_address_prefixes", null)
  resource_group_name        = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name

  depends_on = [azurerm_network_security_group.nsg]
}

# Predefined common rules (Web Server NSG)
locals {
  common_web_rules = var.create_common_web_rules ? {
    "Allow_SSH_Inbound" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = var.ssh_source_address_prefix
      destination_address_prefix = "*"
      description              = "Allow SSH inbound from specified source"
    }
    "Allow_HTTP_Inbound" = {
      priority                   = 1010
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "80"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow HTTP inbound from internet"
    }
    "Allow_HTTPS_Inbound" = {
      priority                   = 1020
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "443"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow HTTPS inbound from internet"
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
    "Allow_All_Outbound" = {
      priority                   = 1000
      direction                 = "Outbound"
      access                    = "Allow"
      protocol                  = "*"
      source_port_range         = "*"
      destination_port_range    = "*"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow all outbound traffic"
    }
  } : {}

  # Merge common rules with custom rules, custom rules take precedence
  all_rules = merge(local.common_web_rules, var.security_rules)
}

# Create merged security rules
resource "azurerm_network_security_rule" "all_rules" {
  for_each = local.all_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range          = lookup(each.value, "source_port_range", null)
  source_port_ranges         = lookup(each.value, "source_port_ranges", null)
  destination_port_range     = lookup(each.value, "destination_port_range", null)
  destination_port_ranges    = lookup(each.value, "destination_port_ranges", null)
  source_address_prefix      = lookup(each.value, "source_address_prefix", null)
  source_address_prefixes    = lookup(each.value, "source_address_prefixes", null)
  destination_address_prefix = lookup(each.value, "destination_address_prefix", null)
  destination_address_prefixes = lookup(each.value, "destination_address_prefixes", null)
  resource_group_name        = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = lookup(each.value, "description", "Security rule ${each.key}")

  depends_on = [azurerm_network_security_group.nsg]
}

# Optional subnet association
resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  count = var.subnet_id != null ? 1 : 0
  
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [azurerm_network_security_group.nsg]
}

# Optional network interface association
resource "azurerm_network_interface_security_group_association" "nic_association" {
  for_each = var.network_interface_ids

  network_interface_id      = each.value
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [azurerm_network_security_group.nsg]
}