# Virtual Network and Subnet Module
# This module creates a virtual network with associated subnets in Azure
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

# Create the Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Module      = "vnet_subnet"
    Environment = var.environment
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Create subnets dynamically based on variable input
resource "azurerm_subnet" "subnet" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.address_prefix]

  # Optional service endpoints
  service_endpoints = lookup(each.value, "service_endpoints", null)

  # Optional delegation
  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }

  depends_on = [azurerm_virtual_network.vnet]
}

# Optional: Route table association
resource "azurerm_route_table" "rt" {
  for_each = {
    for k, v in var.subnets : k => v
    if lookup(v, "create_route_table", false)
  }

  name                = "${each.key}-rt"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Module = "vnet_subnet"
    Subnet = each.key
  })
}

resource "azurerm_subnet_route_table_association" "rt_association" {
  for_each = {
    for k, v in var.subnets : k => v
    if lookup(v, "create_route_table", false)
  }

  subnet_id      = azurerm_subnet.subnet[each.key].id
  route_table_id = azurerm_route_table.rt[each.key].id
}