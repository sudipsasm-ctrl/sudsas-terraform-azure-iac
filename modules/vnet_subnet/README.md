# Virtual Network and Subnet Module

This module creates an Azure Virtual Network (VNet) with associated subnets, providing a foundational networking layer for Azure resources.

## Features

- **Subnet Configuration**: Create multiple subnets with custom address prefixes
- **Service Endpoints**: Optional service endpoints for Azure services
- **Route Tables**: Optional route table creation and association
- **Subnet Delegation**: Support for subnet delegation to Azure services
- **Validation**: Input validation for CIDR blocks and Azure naming conventions
- **Tagging**: Consistent tagging across all resources

## Usage

```hcl
module "network" {
  source = "./modules/vnet_subnet"
  
  vnet_name           = "my-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  
  subnets = {
    web = {
      address_prefix = "10.0.1.0/24"
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
    }
    app = {
      address_prefix     = "10.0.2.0/24"
      create_route_table = true
    }
    data = {
      address_prefix = "10.0.3.0/24"
    }
  }
  
  tags = {
    Environment = "production"
    Project     = "web-application"
  }
}
```

## Usage with Delegation

```hcl
subnets = {
  aks = {
    address_prefix = "10.0.10.0/24"
    delegation = {
      name = "aks-delegation"
      service_delegation = {
        name = "Microsoft.ContainerService/managedClusters"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]
      }
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vnet_name | Name of the virtual network | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| location | Azure region where resources will be deployed | `string` | n/a | yes |
| address_space | Address space for the virtual network | `list(string)` | `["10.0.0.0/16"]` | no |
| subnets | Map of subnets to create | `map(object)` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| environment | Environment name | `string` | `"dev"` | no |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | The ID of the virtual network |
| vnet_name | The name of the virtual network |
| subnet_ids | Map of subnet names to their IDs |
| subnet_names | Map of subnet names to their full names |
| subnet_address_prefixes | Map of subnet names to their address prefixes |
| route_table_ids | Map of route table names to their IDs |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | ~> 3.0 |

## Best Practices

1. **CIDR Planning**: Plan your address spaces carefully to avoid conflicts
2. **Subnet Sizing**: Size subnets appropriately for expected workloads
3. **Service Endpoints**: Use service endpoints for better security and performance
4. **Route Tables**: Create route tables when custom routing is needed
5. **Tagging**: Use consistent tagging for resource organization and cost tracking

## Security Considerations

- Subnets are created without Network Security Groups by default
- Service endpoints should be configured based on security requirements
- Consider using private endpoints for enhanced security
- Plan network segmentation based on security zones