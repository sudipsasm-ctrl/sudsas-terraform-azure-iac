# Assignment 2: System Patch Management
# Automate patch management using Azure Automation and reusable modules
# Author: Senior Azure/Terraform Engineer with 5 years Terraform & 9 years Azure experience

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
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

# Local values for consistent configuration
locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    Owner         = var.owner
    CostCenter    = var.cost_center
    DeployedBy    = "Terraform"
    DeployedAt    = timestamp()
    Assignment    = "Assignment2-Patch-Management"
  }

  # Patch schedule configuration
  patch_schedule_start_time = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timeadd(timestamp(), "${var.patch_schedule_delay_hours}h"))
  
  # Maintenance window start time (next Sunday at configured time)
  maintenance_window_start = formatdate("YYYY-MM-DD'T'${var.maintenance_window_start_hour}:00:00Z", 
    timeadd(timestamp(), "${7 - tonumber(formatdate("w", timestamp()))}*24h"))

  # Update deployment schedules
  update_schedules = [
    {
      name = "${var.project_name}-critical-updates"
      includedClassifications = ["Critical", "Security"]
      excludedPackages = var.excluded_packages
      includedPackages = []
      rebootSetting = var.reboot_setting
      frequency = "Week"
      interval = 1
      startTime = local.patch_schedule_start_time
      timeZone = var.timezone
      duration = "PT${var.patch_window_duration_hours}H"
      targetTags = {
        PatchGroup = var.patch_group_critical
        Environment = var.environment
      }
    },
    {
      name = "${var.project_name}-regular-updates"
      includedClassifications = ["Critical", "Security", "Other"]
      excludedPackages = var.excluded_packages
      includedPackages = []
      rebootSetting = var.reboot_setting
      frequency = "Week"
      interval = 1
      startTime = timeadd(local.patch_schedule_start_time, "24h")
      timeZone = var.timezone
      duration = "PT${var.patch_window_duration_hours}H"
      targetTags = {
        PatchGroup = var.patch_group_regular
        Environment = var.environment
      }
    }
  ]

  # Action groups configuration for alerting
  action_groups = {
    "patch-management-alerts" = {
      short_name = "PatchMgmt"
      email_receivers = [
        {
          name          = "admin-notifications"
          email_address = var.admin_email
        }
      ]
      webhook_receivers = var.webhook_url != null ? [
        {
          name                    = "teams-notifications"
          service_uri            = var.webhook_url
          use_common_alert_schema = true
        }
      ] : []
    }
  }

  # Log alerts for patch management monitoring
  log_alerts = {
    "patch-deployment-failure" = {
      evaluation_frequency = "PT5M"
      window_duration     = "PT30M"
      severity           = 1
      description        = "Alert when patch deployment fails"
      action_group_key   = "patch-management-alerts"
      criteria = {
        query = <<-EOQ
          AzureDiagnostics
          | where Category == "JobLogs" 
          | where RunbookName_s contains "PatchManagement"
          | where ResultType == "Failed"
          | summarize count() by bin(TimeGenerated, 5m)
        EOQ
        time_aggregation_method = "Count"
        threshold              = 1
        operator               = "GreaterThan"
      }
    }
    "high-patch-failure-rate" = {
      evaluation_frequency = "PT15M"
      window_duration     = "PT1H"
      severity           = 2
      description        = "Alert when patch failure rate is high"
      action_group_key   = "patch-management-alerts"
      criteria = {
        query = <<-EOQ
          Update
          | where TimeGenerated > ago(1h)
          | where UpdateState == "Failed"
          | summarize FailedUpdates = count() by Computer
          | where FailedUpdates > 5
        EOQ
        time_aggregation_method = "Count"
        threshold              = 1
        operator               = "GreaterThan"
      }
    }
  }
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

  # Solutions for Update Management
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
  }

  # Enhanced saved searches for patch management
  saved_searches = {
    "Pending_Updates_By_Computer" = {
      category     = "Update Management"
      display_name = "Pending Updates by Computer"
      query        = "Update | where UpdateState == 'Needed' and Optional == false | summarize count() by Computer | order by count_ desc"
    }
    "Failed_Updates_Last_24h" = {
      category     = "Update Management"  
      display_name = "Failed Updates (Last 24 hours)"
      query        = "Update | where TimeGenerated > ago(24h) and UpdateState == 'Failed' | project TimeGenerated, Computer, Title, Classification"
    }
    "Computers_Requiring_Reboot" = {
      category     = "Update Management"
      display_name = "Computers Requiring Reboot"
      query        = "UpdateSummary | where RestartPending == true | project Computer, LastUpdateCheck = TimeGenerated"
    }
    "Update_Deployment_History" = {
      category     = "Update Management"
      display_name = "Update Deployment History"
      query        = "UpdateRunProgress | summarize count() by UpdateRunName, InstallationStatus | order by UpdateRunName desc"
    }
  }

  # Alerting configuration
  action_groups = local.action_groups
  log_alerts    = local.log_alerts

  # Data collection configuration
  create_data_collection_rule = true
  collect_syslog_data        = true
  collect_performance_data   = true

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "Monitoring"
    Purpose   = "Update-Management-Logging"
  })
}

# Module: Azure Automation Account
module "automation_account" {
  source = "../modules/azure_automation"

  automation_account_name = "${var.project_name}-automation"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  sku_name               = var.automation_sku

  # Patch Management Configuration
  create_patch_runbooks  = true
  create_patch_schedule  = true
  patch_schedule_name    = "${var.project_name}-weekly-patches"
  patch_schedule_start_time = local.patch_schedule_start_time
  patch_schedule_days    = var.patch_schedule_days
  timezone              = var.timezone

  # Maintenance Configuration
  create_maintenance_configuration = true
  maintenance_window_start_time   = local.maintenance_window_start
  maintenance_window_duration     = "PT${var.patch_window_duration_hours}H"
  linux_patch_classifications     = var.patch_classifications
  linux_packages_to_exclude      = var.excluded_packages
  reboot_setting                 = var.reboot_setting

  # Automation modules and variables
  install_az_modules = true
  patch_group_name   = var.patch_group_regular

  # Webhooks for external integration
  create_patch_webhook = var.enable_webhook

  # Role assignments
  assign_automation_contributor_role = true
  assign_vm_contributor_role        = true

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "Automation"
    Purpose   = "Patch-Management"
  })
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
  data_collection_rule_id               = module.log_analytics.data_collection_rule_id
  maintenance_configuration_id          = module.automation_account.maintenance_configuration_id

  # VM Configuration (empty for this assignment, will be populated in bonus assignment)
  virtual_machine_ids = var.test_vm_ids

  # Update Management Configuration
  configure_update_management = true
  configure_vm_tags          = true
  patch_group_tag           = var.patch_group_regular
  environment_tag           = var.environment
  schedule_tag              = join(",", var.patch_schedule_days)
  maintenance_window_tag    = "${var.maintenance_window_start_hour}:00-${var.maintenance_window_start_hour + var.patch_window_duration_hours}:00"

  # Update schedules
  create_update_schedules = true
  update_schedules       = local.update_schedules

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "Update-Management"
  })

  depends_on = [
    module.log_analytics,
    module.automation_account
  ]
}

# Create sample VM for testing (optional)
resource "azurerm_virtual_network" "test_vnet" {
  count               = var.create_test_vm ? 1 : 0
  name                = "${var.project_name}-test-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(local.common_tags, {
    Component = "Test-Networking"
  })
}

resource "azurerm_subnet" "test_subnet" {
  count                = var.create_test_vm ? 1 : 0
  name                 = "test-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.test_vnet[0].name
  address_prefixes     = ["10.2.1.0/24"]
}

module "test_vm" {
  count  = var.create_test_vm ? 1 : 0
  source = "../modules/virtual_machine"

  vm_name             = "${var.project_name}-test-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.test_subnet[0].id

  vm_size          = "Standard_B1s"
  admin_username   = var.admin_username
  generate_ssh_key = true

  # Minimal configuration for testing
  create_public_ip                = false
  install_web_server             = false
  install_azure_monitor_agent    = true
  identity_type                  = "SystemAssigned"

  # Tag for update management
  tags = merge(local.common_tags, {
    Component      = "Test-VM"
    PatchGroup     = var.patch_group_regular
    UpdateSchedule = join(",", var.patch_schedule_days)
  })
}

# Update test VM IDs in update management if created
resource "azurerm_maintenance_assignment_virtual_machine" "test_vm_patch_assignment" {
  count = var.create_test_vm ? 1 : 0

  location                     = azurerm_resource_group.main.location
  maintenance_configuration_id = module.automation_account.maintenance_configuration_id
  virtual_machine_id          = module.test_vm[0].vm_id
}