# Virtual Machine Module

This module creates an Azure Linux Virtual Machine with configuration options, cloud-init support, and web server installation capabilities.

## Features

- **Automated Web Server Setup**: Installs and configures Nginx or Apache with cloud-init
- **SSH Key Management**: Generate SSH keys automatically or use existing keys
- **Security Hardening**: Includes UFW firewall, Fail2Ban, and security headers
- **Networking**: Support for public/private IPs and custom network configurations
- **Managed Disks**: Configurable OS and data disks with various storage types
- **Azure Integration**: Optional Azure Monitor Agent and managed identity support
- **Cloud-Init**: Cloud-init configuration with custom script support
- **Extension Support**: VM extensions for additional configuration options

## Usage

### Basic Web Server VM

```hcl
module "web_vm" {
  source = "./modules/virtual_machine"
  
  vm_name             = "web-server-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids["web"]
  
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"
  admin_ssh_key  = file("~/.ssh/id_rsa.pub")
  
  # Web server configuration
  install_web_server = true
  web_server_type   = "nginx"
  
  # Create public IP for internet access
  create_public_ip = true
  
  tags = {
    Environment = "production"
    Purpose     = "web-server"
  }
}
```

### VM with Generated SSH Key and Monitoring

```hcl
module "monitored_vm" {
  source = "./modules/virtual_machine"
  
  vm_name             = "monitored-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids["app"]
  
  # Auto-generate SSH key
  generate_ssh_key = true
  
  # Enhanced configuration
  vm_size                     = "Standard_D2s_v3"
  os_disk_storage_account_type = "Premium_LRS"
  
  # Add data disk
  create_data_disk             = true
  data_disk_size_gb           = 256
  data_disk_storage_account_type = "Premium_LRS"
  
  # Enable monitoring
  install_azure_monitor_agent = true
  identity_type               = "SystemAssigned"
  
  # Custom web server configuration
  web_server_type = "apache"
  custom_cloud_init_script = <<-EOF
    - echo "Custom configuration applied" > /tmp/custom.log
    - systemctl enable apache2
  EOF
}
```

### Private VM without Public IP

```hcl
module "private_vm" {
  source = "./modules/virtual_machine"
  
  vm_name             = "private-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids["private"]
  
  # No public IP - private access only
  create_public_ip = false
  
  # Static private IP
  private_ip_allocation_method = "Static"
  private_ip_address          = "10.0.3.10"
  
  # Disable web server for internal use
  install_web_server = false
  
  # Custom OS image
  vm_image_publisher = "RedHat"
  vm_image_offer     = "RHEL"
  vm_image_sku      = "8-LVM"
}
```

### VM with Custom Extension

```hcl
module "custom_vm" {
  source = "./modules/virtual_machine"
  
  vm_name             = "custom-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids["app"]
  
  admin_ssh_key = var.ssh_public_key
  
  # Use VM extension instead of cloud-init
  use_vm_extension     = true
  custom_script_uri    = "https://raw.githubusercontent.com/your-org/scripts/main/setup.sh"
  custom_script_command = "bash setup.sh"
  
  # Disable default web server installation
  install_web_server = false
}
```

## Cloud-Init Features

The module includes a cloud-init configuration that:

- **Updates and upgrades** the system packages
- **Installs security tools**: UFW firewall, Fail2Ban
- **Configures web servers** with security headers and best practices
- **Sets up automatic security updates**
- **Creates a custom landing page** showing server status
- **Applies security hardening** configurations

### Supported Web Servers

#### Nginx Configuration
- Modern nginx configuration with security headers
- Optimized for performance and security
- Custom error pages and logging

#### Apache Configuration
- Apache 2.4 configuration with mod_headers and mod_rewrite
- Security-focused virtual host configuration
- Performance optimizations

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vm_name | Name of the virtual machine | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| location | Azure region for deployment | `string` | n/a | yes |
| subnet_id | ID of the subnet for VM deployment | `string` | n/a | yes |
| vm_size | Size of the virtual machine | `string` | `"Standard_B2s"` | no |
| admin_username | Admin username for the VM | `string` | `"azureuser"` | no |
| admin_ssh_key | SSH public key for authentication | `string` | `null` | no |
| generate_ssh_key | Auto-generate SSH key pair | `bool` | `false` | no |
| install_web_server | Install and configure web server | `bool` | `true` | no |
| web_server_type | Type of web server (nginx/apache) | `string` | `"nginx"` | no |
| create_public_ip | Create and assign public IP | `bool` | `true` | no |
| create_data_disk | Create and attach data disk | `bool` | `false` | no |
| install_azure_monitor_agent | Install Azure Monitor Agent | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | The ID of the virtual machine |
| vm_name | The name of the virtual machine |
| public_ip_address | Public IP address (if created) |
| private_ip_address | Private IP address |
| ssh_connection_command | SSH command to connect to VM |
| web_server_url | URL to access web server |
| ssh_private_key | Generated SSH private key (sensitive) |
| network_interface_id | ID of the network interface |
| system_assigned_identity_principal_id | Principal ID of system identity |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | ~> 3.0 |
| tls | ~> 4.0 |

## Security Features

### Cloud-Init Security Hardening
- **UFW Firewall**: Configured with default deny and specific allow rules
- **Fail2Ban**: Protection against brute-force attacks
- **Automatic Updates**: Unattended security updates enabled
- **Security Headers**: Web server configured with security headers
- **SSH Hardening**: Password authentication disabled, key-based only

### Network Security
- Support for Network Security Group integration
- Private IP allocation options
- Optional public IP assignment
- Subnet-level network isolation

## Best Practices

1. **SSH Key Management**: Use strong SSH keys and consider key rotation
2. **VM Sizing**: Choose appropriate VM sizes for workload requirements
3. **Storage**: Use Premium SSD for production workloads
4. **Monitoring**: Enable Azure Monitor Agent for monitoring
5. **Identity**: Use managed identities for Azure service integration
6. **Updates**: Keep the cloud-init configuration updated with latest security patches
7. **Backups**: Implement backup strategies for critical VMs
8. **Network**: Use private IPs and bastion hosts for secure access

## Troubleshooting

### Cloud-Init Logs
Check cloud-init logs on the VM:
```bash
sudo cat /var/log/cloud-init-output.log
sudo cloud-init status
```

### Web Server Status
Check web server status:
```bash
# For Nginx
sudo systemctl status nginx
sudo nginx -t

# For Apache
sudo systemctl status apache2
sudo apache2ctl configtest
```

### SSH Connection Issues
- Verify SSH key format and permissions
- Check Network Security Group rules
- Ensure public IP is assigned (if required)
- Verify cloud-init completed successfully