# Azure Automation Account Module
# This module creates Azure Automation Account for patch management and automation
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

# Create the Azure Automation Account
resource "azurerm_automation_account" "automation_account" {
  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name           = var.sku_name

  # Enable system assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Module      = "azure_automation"
    Environment = var.environment
  })
}

# Create runbooks for patch management
resource "azurerm_automation_runbook" "patch_management" {
  count                   = var.create_patch_runbooks ? 1 : 0
  name                    = "PatchManagement-Linux"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = true
  log_progress            = true
  description             = "Runbook for Linux patch management"
  runbook_type           = "PowerShell"

  content = file("${path.module}/runbooks/patch-management.ps1")

  tags = merge(var.tags, {
    Module    = "azure_automation"
    Component = "runbook"
    Purpose   = "patch-management"
  })
}

# Create a schedule for patch deployment
resource "azurerm_automation_schedule" "weekly_patch_schedule" {
  count                   = var.create_patch_schedule ? 1 : 0
  name                    = var.patch_schedule_name
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency              = "Week"
  interval               = 1
  timezone               = var.timezone
  start_time             = var.patch_schedule_start_time
  description            = "Weekly patch deployment schedule"
  week_days              = var.patch_schedule_days
}

# Create maintenance configuration for Update Management
resource "azurerm_maintenance_configuration" "patch_maintenance" {
  count               = var.create_maintenance_configuration ? 1 : 0
  name                = "${var.automation_account_name}-maintenance"
  resource_group_name = var.resource_group_name
  location            = var.location
  scope               = "InGuestPatch"
  visibility          = "Custom"

  window {
    start_date_time      = var.maintenance_window_start_time
    duration             = var.maintenance_window_duration
    time_zone            = var.timezone
    recur_every          = "1Week"
  }

  install_patches {
    linux {
      classification_to_include    = var.linux_patch_classifications
      package_names_mask_to_exclude = var.linux_packages_to_exclude
      package_names_mask_to_include = var.linux_packages_to_include
    }
    reboot = var.reboot_setting
  }

  tags = merge(var.tags, {
    Module    = "azure_automation"
    Component = "maintenance"
  })
}

# Create PowerShell modules for automation
resource "azurerm_automation_module" "az_accounts" {
  count                   = var.install_az_modules ? 1 : 0
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_uri = "https://www.powershellgallery.com/packages/Az.Accounts"
}

resource "azurerm_automation_module" "az_profile" {
  count                   = var.install_az_modules ? 1 : 0
  name                    = "Az.Profile"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_uri = "https://www.powershellgallery.com/packages/Az.Profile"

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_resources" {
  count                   = var.install_az_modules ? 1 : 0
  name                    = "Az.Resources"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_uri = "https://www.powershellgallery.com/packages/Az.Resources"

  depends_on = [azurerm_automation_module.az_profile]
}

# Create automation variables for configuration
resource "azurerm_automation_variable_string" "environment" {
  name                    = "Environment"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  value                   = var.environment
  description             = "Environment name for automation scripts"
}

resource "azurerm_automation_variable_string" "patch_group" {
  name                    = "PatchGroup"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  value                   = var.patch_group_name
  description             = "Patch group identifier for VM grouping"
}

# Create automation credentials if specified
resource "azurerm_automation_credential" "automation_credential" {
  for_each                = var.automation_credentials
  name                    = each.key
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  username                = each.value.username
  password                = each.value.password
  description             = each.value.description
}

# Role assignment for Automation Account Managed Identity
resource "azurerm_role_assignment" "automation_contributor" {
  count                = var.assign_automation_contributor_role ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_automation_account.automation_account.identity[0].principal_id
}

resource "azurerm_role_assignment" "virtual_machine_contributor" {
  count                = var.assign_vm_contributor_role ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.automation_account.identity[0].principal_id
}

# Data source for current subscription
data "azurerm_subscription" "current" {}

# Automation webhook for external triggers
resource "azurerm_automation_webhook" "patch_webhook" {
  count                   = var.create_patch_webhook ? 1 : 0
  name                    = "${var.automation_account_name}-patch-webhook"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.automation_account.name
  expiry_time            = timeadd(timestamp(), "${24 * 365}h") # 1 year from now
  enabled                = true
  runbook_name           = var.create_patch_runbooks ? azurerm_automation_runbook.patch_management[0].name : null

  depends_on = [azurerm_automation_runbook.patch_management]
}