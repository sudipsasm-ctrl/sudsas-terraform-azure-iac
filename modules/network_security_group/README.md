# Network Security Group Module

This module creates an Azure Network Security Group (NSG) with configurable security rules and association capabilities.

## Features

- **Flexible Rule Configuration**: Create custom inbound and outbound security rules
- **Predefined Web Rules**: Option to create common web server rules (SSH, HTTP, HTTPS)
- **Multiple Associations**: Support for subnet and network interface associations
- **Rule Validation**: Input validation for priorities, protocols, and directions
- **Comprehensive Outputs**: Detailed outputs for troubleshooting and integration
- **Tagging Support**: Consistent tagging across resources

## Usage

### Basic NSG with Custom Rules

```hcl
module "web_nsg" {
  source = "./modules/network_security_group"
  
  nsg_name            = "web-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  security_rules = {
    "Allow_SSH" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = "10.0.0.0/8"
      destination_address_prefix = "*"
      description              = "Allow SSH from internal network"
    }
    "Allow_HTTP" = {
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
  }
  
  subnet_id = module.network.subnet_ids["web"]
  
  tags = {
    Environment = "production"
    Purpose     = "web-security"
  }
}
```

### NSG with Predefined Web Rules

```hcl
module "web_nsg_simple" {
  source = "./modules/network_security_group"
  
  nsg_name                   = "web-nsg-simple"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  create_common_web_rules    = true
  ssh_source_address_prefix  = "203.0.113.0/24"  # Your management IP range
  
  subnet_id = module.network.subnet_ids["web"]
}
```

### NSG with Network Interface Association

```hcl
module "vm_nsg" {
  source = "./modules/network_security_group"
  
  nsg_name            = "vm-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  
  security_rules = {
    "Allow_Custom_App" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_ranges   = ["8080", "8443"]
      source_address_prefix     = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }
}
```

## Common Web Rules

When `create_common_web_rules = true`, the following rules are automatically created:

| Rule Name | Priority | Direction | Protocol | Port | Source | Description |
|-----------|----------|-----------|----------|------|--------|-------------|
| Allow_SSH_Inbound | 1000 | Inbound | TCP | 22 | Configurable | SSH access |
| Allow_HTTP_Inbound | 1010 | Inbound | TCP | 80 | Internet | HTTP access |
| Allow_HTTPS_Inbound | 1020 | Inbound | TCP | 443 | Internet | HTTPS access |
| Deny_All_Inbound | 4000 | Inbound | All | All | All | Deny all other inbound |
| Allow_All_Outbound | 1000 | Outbound | All | All | All | Allow all outbound |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| nsg_name | Name of the network security group | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| location | Azure region where the NSG will be deployed | `string` | n/a | yes |
| security_rules | Map of security rules to create | `map(object)` | `{}` | no |
| create_common_web_rules | Create common web server security rules | `bool` | `false` | no |
| ssh_source_address_prefix | Source address prefix for SSH access | `string` | `"*"` | no |
| subnet_id | ID of the subnet to associate with the NSG | `string` | `null` | no |
| network_interface_ids | Set of network interface IDs to associate | `set(string)` | `[]` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| nsg_id | The ID of the network security group |
| nsg_name | The name of the network security group |
| security_rule_names | List of security rule names created |
| allowed_inbound_ports | List of allowed inbound ports |
| inbound_rules | List of inbound security rules |
| outbound_rules | List of outbound security rules |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | ~> 3.0 |

## Security Rule Priority Guidelines

- **100-999**: High priority rules (admin access, critical services)
- **1000-1999**: Application-specific rules
- **2000-2999**: Database and backend services
- **3000-3999**: Monitoring and management
- **4000-4096**: Deny rules (lowest priority)

## Best Practices

1. **Least Privilege**: Only allow necessary ports and protocols
2. **Source Restrictions**: Use specific source address prefixes when possible
3. **Rule Naming**: Use descriptive names for security rules
4. **Priority Planning**: Plan priorities to avoid conflicts
5. **Regular Audits**: Review and audit security rules regularly
6. **Documentation**: Document the purpose of each security rule

## Security Considerations

- Default Azure NSG rules allow outbound internet access
- Consider using Application Security Groups for complex scenarios
- Monitor NSG flow logs for traffic analysis
- Use just-in-time (JIT) VM access for administrative access
- Implement network segmentation based on security requirements