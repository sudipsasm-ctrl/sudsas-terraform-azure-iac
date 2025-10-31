# Complete Azure Infrastructure Environment
# Combining VM deployment with patch management
# Author: Senior Azure/Terraform Engineer with 5 years Terraform & 9 years Azure experience

terraform {
  required_version = ">= 1.0"
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

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Local values for configuration
locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    Owner         = var.owner
    CostCenter    = var.cost_center
    DeployedBy    = "Terraform"
    DeployedAt    = timestamp()
    Assignment    = "Complete-Environment"
  }

  # Network configuration with multiple subnets
  network_config = {
    vnet_address_space = [var.vnet_address_space]
    subnets = {
      web = {
        address_prefix = var.web_subnet_cidr
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
      }
      app = {
        address_prefix = var.app_subnet_cidr
        service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
      }
      data = {
        address_prefix = var.data_subnet_cidr
        service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
      }
      management = {
        address_prefix = var.management_subnet_cidr
        service_endpoints = ["Microsoft.Storage"]
      }
    }
  }

  # Security rules for different tiers
  web_security_rules = {
    "Allow_SSH_Management" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = var.management_source_ip
      destination_address_prefix = "*"
      description              = "Allow SSH from management"
    }
    "Allow_HTTP_Internet" = {
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
    "Allow_HTTPS_Internet" = {
      priority                   = 1020
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "443"
      source_address_prefix     = "*"
      destination_address_prefix = "*"
      description              = "Allow HTTPS from internet"
    }
  }

  app_security_rules = {
    "Allow_SSH_Management" = {
      priority                   = 1000
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "22"
      source_address_prefix     = var.management_source_ip
      destination_address_prefix = "*"
      description              = "Allow SSH from management"
    }
    "Allow_App_From_Web" = {
      priority                   = 1010
      direction                 = "Inbound"
      access                    = "Allow"
      protocol                  = "Tcp"
      source_port_range         = "*"
      destination_port_range    = "8080"
      source_address_prefix     = var.web_subnet_cidr
      destination_address_prefix = "*"
      description              = "Allow app traffic from web tier"
    }
  }

  # Patch schedule configuration
  patch_schedule_start_time = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timeadd(timestamp(), "${var.patch_schedule_delay_hours}h"))
  maintenance_window_start = formatdate("YYYY-MM-DD'T'${var.maintenance_window_start_hour}:00:00Z", 
    timeadd(timestamp(), "${7 - tonumber(formatdate("w", timestamp()))}*24h"))

  # VM configurations for different tiers
  web_vms = {
    for i in range(var.web_vm_count) : "web-${i + 1}" => {
      vm_size     = var.web_vm_size
      patch_group = "web-servers"
      subnet      = "web"
      install_web_server = true
      web_server_type = var.web_server_type
    }
  }

  app_vms = {
    for i in range(var.app_vm_count) : "app-${i + 1}" => {
      vm_size     = var.app_vm_size
      patch_group = "app-servers"
      subnet      = "app"
      install_web_server = false
      web_server_type = null
    }
  }

  all_vms = merge(local.web_vms, local.app_vms)
}

# Module: Virtual Network and Subnets
module "network" {
  source = "../modules/vnet_subnet"

  vnet_name           = "${var.project_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = local.network_config.vnet_address_space
  subnets             = local.network_config.subnets
  environment         = var.environment

  tags = merge(local.common_tags, {
    Component = "Networking"
  })
}

# Module: Log Analytics Workspace
module "log_analytics" {
  source = "../modules/log_analytics"

  workspace_name      = "${var.project_name}-law"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                = var.log_analytics_sku
  retention_in_days  = var.log_retention_days
  daily_quota_gb     = var.daily_quota_gb

  # Solutions
  solutions = {
    "Updates" = {
      publisher = "Microsoft"
      product   = "OMSGallery/Updates"
    }
    "VMInsights" = {
      publisher = "Microsoft"
      product   = "OMSGallery/VMInsights"
    }
    "Security" = {
      publisher = "Microsoft"
      product   = "OMSGallery/Security"
    }
    "ChangeTracking" = {
      publisher = "Microsoft"
      product   = "OMSGallery/ChangeTracking"
    }
    "NetworkMonitoring" = {
      publisher = "Microsoft"
      product   = "OMSGallery/NetworkMonitoring"
    }
  }

  # Enhanced monitoring queries
  saved_searches = {
    "Infrastructure_Health" = {
      category     = "Infrastructure"
      display_name = "Infrastructure Health Overview"
      query        = "Heartbeat | summarize LastHeartbeat = max(TimeGenerated) by Computer | where LastHeartbeat < ago(5m)"
    }
    "Security_Events_Summary" = {
      category     = "Security"
      display_name = "Security Events Summary"
      query        = "SecurityEvent | summarize count() by EventID, Account | order by count_ desc"
    }
    "Performance_Issues" = {
      category     = "Performance"
      display_name = "Performance Issues"
      query        = "Perf | where CounterName in ('% Processor Time', '% Used Memory') and CounterValue > 90 | project TimeGenerated, Computer, CounterName, CounterValue"
    }
  }

  # Alerting configuration
  action_groups = {
    "infrastructure-alerts" = {
      short_name = "InfraAlert"
      email_receivers = [
        {
          name          = "admin-notifications"
          email_address = var.admin_email
        }
      ]
    }
  }

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "Monitoring"
  })
}

# Module: Azure Automation Account
module "automation_account" {
  source = "../modules/azure_automation"

  automation_account_name = "${var.project_name}-automation"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location

  # Patch management
  create_patch_runbooks           = true
  create_patch_schedule          = true
  patch_schedule_start_time      = local.patch_schedule_start_time
  patch_schedule_days           = var.patch_schedule_days
  create_maintenance_configuration = true
  maintenance_window_start_time  = local.maintenance_window_start
  maintenance_window_duration    = "PT${var.patch_window_duration_hours}H"
  reboot_setting                = var.reboot_setting

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "Automation"
  })
}

# Module: Network Security Groups
module "web_nsg" {
  source = "../modules/network_security_group"

  nsg_name            = "${var.project_name}-web-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  security_rules      = local.web_security_rules
  subnet_id           = module.network.subnet_ids["web"]

  tags = merge(local.common_tags, {
    Component = "Security"
    Tier      = "Web"
  })
}

module "app_nsg" {
  source = "../modules/network_security_group"

  nsg_name            = "${var.project_name}-app-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  security_rules      = local.app_security_rules
  subnet_id           = module.network.subnet_ids["app"]

  tags = merge(local.common_tags, {
    Component = "Security"
    Tier      = "Application"
  })
}

# Module: Virtual Machines
module "virtual_machines" {
  for_each = local.all_vms
  source   = "../modules/virtual_machine"

  vm_name             = "${var.project_name}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.network.subnet_ids[each.value.subnet]

  vm_size          = each.value.vm_size
  admin_username   = var.admin_username
  generate_ssh_key = each.key == keys(local.all_vms)[0] ? true : false  # Generate key for first VM only
  admin_ssh_key    = each.key == keys(local.all_vms)[0] ? null : module.virtual_machines[keys(local.all_vms)[0]].ssh_public_key

  # Network configuration
  create_public_ip = contains(keys(local.web_vms), each.key)  # Only web VMs get public IPs

  # Storage configuration
  os_disk_storage_account_type = var.os_disk_type
  create_data_disk            = var.create_data_disk
  data_disk_size_gb          = var.data_disk_size_gb

  # Web server configuration
  install_web_server = each.value.install_web_server
  web_server_type   = each.value.web_server_type

  # Monitoring and identity
  identity_type               = "SystemAssigned"
  install_azure_monitor_agent = true

  tags = merge(local.common_tags, {
    Component      = each.value.subnet == "web" ? "Web-Server" : "App-Server"
    Tier           = title(each.value.subnet)
    PatchGroup     = each.value.patch_group
    UpdateSchedule = join(",", var.patch_schedule_days)
  })

  depends_on = [module.network]
}

# Module: Update Management Integration
module "update_management" {
  source = "../modules/update_management"

  resource_group_name                    = azurerm_resource_group.main.name
  location                              = azurerm_resource_group.main.location
  log_analytics_workspace_id            = module.log_analytics.workspace_id
  log_analytics_workspace_customer_id   = module.log_analytics.workspace_customer_id
  log_analytics_workspace_key           = module.log_analytics.primary_shared_key
  automation_account_id                 = module.automation_account.automation_account_id
  automation_account_name               = module.automation_account.automation_account_name
  maintenance_configuration_id          = module.automation_account.maintenance_configuration_id

  # VM integration
  virtual_machine_ids = {
    for vm_name, vm in module.virtual_machines : vm_name => vm.vm_id
  }

  configure_update_management = true
  configure_vm_tags          = true

  tags = merge(local.common_tags, {
    Component = "Update-Management"
  })

  depends_on = [
    module.log_analytics,
    module.automation_account,
    module.virtual_machines
  ]
}