# Azure & Terraform Infrastructure as Code - Modular Approach

This repository contains an Azure infrastructure deployment using modular Terraform configurations. Built with production-ready practices, security hardening, and patch management capabilities.

## Architecture Overview

**Infrastructure Components:**
- **Virtual Network** with 3 subnets (Web: 10.x.1.0/24, App: 10.x.2.0/24, Data: 10.x.3.0/24)
- **Virtual Machines** (Web Server with public IP, App Server private only)
- **Log Analytics Workspace** (VM Insights, Security, Updates, Change Tracking)
- **Automation Account** (Update Management, Patch Runbooks, Maintenance Schedules)

**Network Flow:**
```
Internet → Web Server VM (Public IP) → App Server VM → Data Subnet
           ↓
    Log Analytics ← Automation Account
```

## Repository Structure

**Terraform Modules:**
- `modules/vnet_subnet/` - Virtual Network & Subnets
- `modules/network_security_group/` - Network Security Groups  
- `modules/virtual_machine/` - Virtual Machine with cloud-init
- `modules/azure_automation/` - Automation Account & Update Management
- `modules/log_analytics/` - Log Analytics Workspace
- `modules/update_management/` - Update Management Integration

**Assignment Solutions:**
- `assignment1-vm-networking/` - VM & Networking deployment
- `assignment2-patch-management/` - Patch Management setup
- `complete-environment/` - Complete multi-tier environment

## Assignment Solutions

### Assignment 1: Virtual Machines & Networking

**Objective**: Set up a secure Linux web server using reusable Terraform modules.

**Implementation**: [`assignment1-vm-networking/`](./assignment1-vm-networking/)

**Key Features**:
- **Reusable Modules**: VNet/Subnet, NSG, Virtual Machine
- **Secure VM**: Linux with NGINX/Apache via cloud-init
- **Network Security**: Ports 22 and 80 exposed via NSG rules
- **Public IP Output**: Accessible web server with public IP
- **SSH Access**: Key-based authentication with generated keys

**Key Components**:
```hcl
# Usage Example
module "network" {
  source = "../modules/vnet_subnet"
  vnet_name = "assignment1-vnet"
  subnets = {
    web = {
      address_prefix = "10.1.1.0/24"
      service_endpoints = ["Microsoft.Storage"]
    }
  }
}

module "web_server" {
  source = "../modules/virtual_machine"
  vm_name = "web-server-01"
  subnet_id = module.network.subnet_ids["web"]
  install_web_server = true
  web_server_type = "nginx"
}
```

**Deployment**:
```bash
cd assignment1-vm-networking/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Assignment 2: System Patch Management

**Objective**: Automate patch management using Azure Automation and reusable modules.

**Implementation**: [`assignment2-patch-management/`](./assignment2-patch-management/)

**Key Features**:
- **Automation Account Module**: Full patch management
- **Log Analytics Module**: Monitoring and compliance reporting
- **Update Management Integration**: VM linking and configuration
- **Weekly Patch Schedule**: Automated deployment scheduling
- **Compliance Monitoring**: Dashboard and alerting capabilities

**Key Components**:
```hcl
# Usage Example
module "log_analytics" {
  source = "../modules/log_analytics"
  workspace_name = "patch-mgmt-law"
  solutions = {
    "Updates" = { publisher = "Microsoft", product = "OMSGallery/Updates" }
  }
}

module "automation_account" {
  source = "../modules/azure_automation"
  create_maintenance_configuration = true
  patch_schedule_days = ["Sunday"]
  reboot_setting = "IfRequired"
}
```

**Patch Management Features**:
- **Automated Runbooks**: PowerShell scripts for Linux patching
- **Scheduled Deployments**: Weekly maintenance windows
- **Compliance Reporting**: Real-time patch status monitoring
- **Alerting**: Email and webhook notifications for failures
- **VM Grouping**: Tag-based patch group management

### Bonus Challenge: Complete Environment

**Objective**: Combine all modules into a single, parameterized environment.

**Implementation**: [`complete-environment/`](./complete-environment/)

**Key Features**:
- **Multi-tier Architecture**: Web, App, and Data subnets
- **Scalable VM Deployment**: Configurable VM count per tier
- **Integrated Patch Management**: All VMs enrolled automatically
- **Complete Monitoring**: Full observability stack
- **Enhanced Security**: Tier-based NSG rules and network segmentation
- **Enterprise Tags**: Consistent tagging strategy

## Module Documentation

### Core Modules

| Module | Purpose | Key Features |
|--------|---------|--------------|
| **[vnet_subnet](./modules/vnet_subnet/)** | Network Foundation | Multiple subnets, service endpoints, route tables |
| **[network_security_group](./modules/network_security_group/)** | Network Security | Custom rules, predefined templates, multi-association |
| **[virtual_machine](./modules/virtual_machine/)** | Compute Resources | Cloud-init, SSH keys, web server installation |
| **[azure_automation](./modules/azure_automation/)** | Automation & Patching | Runbooks, schedules, maintenance configs |
| **[log_analytics](./modules/log_analytics/)** | Monitoring & Logging | Solutions, alerts, saved searches |
| **[update_management](./modules/update_management/)** | Patch Integration | VM linking, data collection, compliance |

### Key Features

#### Security Hardening
- **SSH Key Management**: Auto-generation with secure storage
- **Network Segmentation**: Subnet-based isolation with NSG rules
- **Service Endpoints**: Secure Azure service connectivity
- **Firewall Configuration**: UFW and Fail2Ban integration
- **Security Headers**: Web server hardening

#### Cloud-Init Integration
```yaml
#cloud-config
packages:
  - nginx
  - ufw
  - fail2ban

runcmd:
  - ufw --force enable
  - ufw allow ssh
  - ufw allow 80/tcp
  - systemctl enable nginx
  - systemctl start nginx
```

#### Monitoring and Analytics
- **VM Insights**: Performance and health monitoring
- **Security Center**: Vulnerability assessments
- **Update Compliance**: Patch status tracking
- **Custom Dashboards**: Infrastructure health overview
- **Proactive Alerts**: Email and webhook notifications

### Deployment Instructions

### Prerequisites
- Azure CLI installed and configured
- Terraform >= 1.0
- Azure subscription with appropriate permissions

### 1. Clone Repository
```bash
git clone https://github.com/your-org/sudsas-terraform-azure-iac.git
cd sudsas-terraform-azure-iac
```

### 2. Choose Your Deployment

#### Quick Web Server (Assignment 1)
```bash
cd assignment1-vm-networking/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply
```

#### Patch Management Setup (Assignment 2)
```bash
cd assignment2-patch-management/
terraform init && terraform apply
```

#### Complete Environment (Bonus)
```bash
cd complete-environment/
terraform init && terraform apply
```

### 3. Access Your Infrastructure
```bash
# Get web server URL
terraform output web_server_url

# Get SSH connection command
terraform output ssh_connection_command

# View patch management portal
echo "Visit Azure Portal > Automation Accounts > Update Management"
```

### Scaling and Performance

### Patch Management Dashboard
Access patch compliance through:
1. **Azure Portal** → Automation Accounts → Update Management
2. **Log Analytics Workspace** → Saved Searches → Update queries
3. **Azure Monitor** → Workbooks → Update Management

### Key Metrics Monitored
- Patch compliance percentage
- Last successful patch deployment
- Failed update installations
- Pending system reboots
- Security update status

### Troubleshooting Commands
```bash
# Check cloud-init status
sudo cloud-init status

# View patch management logs
sudo tail -f /var/log/azure-update-management/configuration.log

# Test connectivity to Log Analytics
curl -v https://ods.opinsights.azure.com/

# Check Azure Monitor Agent status
systemctl status azuremonitoragent
```

### Security Considerations

### Network Security
- **Principle of Least Privilege**: Minimal required access
- **Network Segmentation**: Subnet isolation with NSGs
- **Service Endpoints**: Secure Azure service access
- **Public IP Limitation**: Only web tier has internet access

### VM Security
- **SSH Key Authentication**: No password authentication
- **Automatic Updates**: Managed through Azure Update Management
- **Firewall Configuration**: UFW with strict rules
- **Security Monitoring**: Azure Security Center integration

### Operational Security
- **Managed Identities**: No stored credentials
- **Role-Based Access**: Granular permission assignment
- **Audit Logging**: Activity tracking
- **Backup Strategy**: Automated VM and data backups

### Cost Optimization

### Resource Sizing Recommendations
| Environment | VM Size | Storage | Estimated Monthly Cost |
|-------------|---------|---------|----------------------|
| **Development** | Standard_B1s | Standard_LRS | ~$30-50 |
| **Testing** | Standard_B2s | StandardSSD_LRS | ~$60-100 |
| **Production** | Standard_D2s_v3 | Premium_LRS | ~$150-250 |

### Cost-Saving Features
- **Resource Tagging**: Cost center tracking and allocation
- **Auto-Shutdown**: Development VM scheduling
- **Right-Sizing**: Performance-based recommendations
- **Storage Optimization**: Appropriate disk types per workload

### Contributing

### Code Standards
- **Terraform Style**: Follow [HashiCorp style guide](https://www.terraform.io/docs/language/syntax/style.html)
- **Module Structure**: Consistent `main.tf`, `variables.tf`, `outputs.tf`
- **Documentation**: README for each module
- **Validation**: Input validation and error handling

### Testing Approach
```bash
# Validate Terraform syntax
terraform validate

# Security scanning
tfsec .

# Format code
terraform fmt -recursive

# Plan verification
terraform plan -detailed-exitcode
```

### Support

### Operational Runbooks
- **Deployment Guide**: Step-by-step deployment instructions
- **Troubleshooting**: Common issues and solutions
- **Backup & Recovery**: Data protection procedures
- **Security Incident Response**: Security event handling

### Monitoring & Alerting
- **Infrastructure Health**: VM availability and performance
- **Security Events**: Failed logins and vulnerability alerts
- **Patch Compliance**: Update deployment status
- **Cost Alerts**: Budget threshold notifications

### Best Practices

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| **Reusable Modules** | Complete | 6 production modules |
| **VM Deployment** | Complete | Cloud-init with web server |
| **Network Security** | Complete | NSGs with ports 22/80 exposed |
| **Public IP Output** | Complete | Web server accessible via internet |
| **Automation Account** | Complete | Full patch management capabilities |
| **Update Management** | Complete | VM linking and scheduling |
| **Weekly Scheduling** | Complete | Configurable maintenance windows |
| **Monitoring Setup** | Complete | Log Analytics with solutions |
| **Complete Environment** | Complete | Multi-tier parameterized deployment |
| **Documentation** | Complete | Complete guides and examples |

---

## About the Implementation

This infrastructure shows **production Azure deployment practices** combining:

- **5 years of Terraform expertise**: Module patterns, state management, and CI/CD integration
- **6 years of Azure experience**: Platform knowledge, security practices, and operational experience
- **DevOps Engineering**: Infrastructure as Code, monitoring, and patch management
- **Security Focus**: Defense in depth, compliance frameworks, and threat mitigation
- **Operational Excellence**: Monitoring, alerting, cost optimization, and disaster recovery

The solution covers real-world scenarios including multi-tier architectures, patch management, monitoring, and security controls that I've implemented across various production environments.

---

Sudipto S
