# Outputs for Azure Automation Account Module
# Provides comprehensive output information for integration with other modules

output "automation_account_id" {
  description = "The ID of the Automation Account"
  value       = azurerm_automation_account.automation_account.id
}

output "automation_account_name" {
  description = "The name of the Automation Account"
  value       = azurerm_automation_account.automation_account.name
}

output "automation_account_location" {
  description = "The location of the Automation Account"
  value       = azurerm_automation_account.automation_account.location
}

output "automation_account_resource_group" {
  description = "The resource group of the Automation Account"
  value       = azurerm_automation_account.automation_account.resource_group_name
}

output "automation_account_sku" {
  description = "The SKU of the Automation Account"
  value       = azurerm_automation_account.automation_account.sku_name
}

# Managed Identity Information
output "system_assigned_identity_principal_id" {
  description = "The principal ID of the system assigned managed identity"
  value       = azurerm_automation_account.automation_account.identity[0].principal_id
}

output "system_assigned_identity_tenant_id" {
  description = "The tenant ID of the system assigned managed identity"
  value       = azurerm_automation_account.automation_account.identity[0].tenant_id
}

# Runbook Information
output "patch_runbook_id" {
  description = "The ID of the patch management runbook"
  value       = var.create_patch_runbooks ? azurerm_automation_runbook.patch_management[0].id : null
}

output "patch_runbook_name" {
  description = "The name of the patch management runbook"
  value       = var.create_patch_runbooks ? azurerm_automation_runbook.patch_management[0].name : null
}

# Schedule Information
output "patch_schedule_id" {
  description = "The ID of the patch deployment schedule"
  value       = var.create_patch_schedule ? azurerm_automation_schedule.weekly_patch_schedule[0].id : null
}

output "patch_schedule_name" {
  description = "The name of the patch deployment schedule"
  value       = var.create_patch_schedule ? azurerm_automation_schedule.weekly_patch_schedule[0].name : null
}

output "patch_schedule_next_run" {
  description = "The next run time of the patch schedule"
  value       = var.create_patch_schedule ? azurerm_automation_schedule.weekly_patch_schedule[0].start_time : null
}

# Maintenance Configuration
output "maintenance_configuration_id" {
  description = "The ID of the maintenance configuration"
  value       = var.create_maintenance_configuration ? azurerm_maintenance_configuration.patch_maintenance[0].id : null
}

output "maintenance_configuration_name" {
  description = "The name of the maintenance configuration"
  value       = var.create_maintenance_configuration ? azurerm_maintenance_configuration.patch_maintenance[0].name : null
}

# Module Installation Status
output "az_modules_installed" {
  description = "Whether Azure PowerShell modules are installed"
  value       = var.install_az_modules
}

output "installed_modules" {
  description = "List of installed automation modules"
  value = var.install_az_modules ? [
    "Az.Accounts",
    "Az.Profile", 
    "Az.Resources"
  ] : []
}

# Webhook Information
output "patch_webhook_id" {
  description = "The ID of the patch management webhook"
  value       = var.create_patch_webhook ? azurerm_automation_webhook.patch_webhook[0].id : null
}

output "patch_webhook_uri" {
  description = "The URI of the patch management webhook"
  value       = var.create_patch_webhook ? azurerm_automation_webhook.patch_webhook[0].uri : null
  sensitive   = true
}

# Automation Variables
output "automation_variables" {
  description = "Map of automation variables created"
  value = {
    Environment = azurerm_automation_variable_string.environment.value
    PatchGroup  = azurerm_automation_variable_string.patch_group.value
  }
}

# Credential Information
output "automation_credentials" {
  description = "List of automation credential names"
  value       = keys(var.automation_credentials)
}

# Role Assignment Information
output "role_assignments" {
  description = "Information about role assignments"
  value = {
    automation_contributor_assigned = var.assign_automation_contributor_role
    vm_contributor_assigned        = var.assign_vm_contributor_role
  }
}

# Configuration Summary
output "patch_management_configuration" {
  description = "Summary of patch management configuration"
  value = {
    runbook_created             = var.create_patch_runbooks
    schedule_created           = var.create_patch_schedule
    maintenance_config_created = var.create_maintenance_configuration
    webhook_created           = var.create_patch_webhook
    patch_schedule_days       = var.patch_schedule_days
    maintenance_window_duration = var.maintenance_window_duration
    reboot_setting            = var.reboot_setting
    timezone                  = var.timezone
    patch_group_name          = var.patch_group_name
  }
}

# Update Management Settings
output "update_management_settings" {
  description = "Update management configuration details"
  value = var.create_maintenance_configuration ? {
    linux_classifications = var.linux_patch_classifications
    excluded_packages    = var.linux_packages_to_exclude
    included_packages    = var.linux_packages_to_include
    reboot_setting       = var.reboot_setting
    maintenance_window   = var.maintenance_window_duration
  } : null
}

# DSC Configuration
output "dsc_configurations" {
  description = "List of DSC configurations"
  value       = keys(var.dsc_configurations)
}

# Hybrid Worker Groups
output "hybrid_worker_groups" {
  description = "List of hybrid worker group names"
  value       = keys(var.hybrid_worker_groups)
}

# Diagnostic Settings
output "diagnostic_settings_enabled" {
  description = "Whether diagnostic settings are enabled"
  value       = var.enable_diagnostic_settings
}

# Connection Information for VMs
output "vm_connection_info" {
  description = "Information needed for VM connections to Update Management"
  value = {
    automation_account_id   = azurerm_automation_account.automation_account.id
    maintenance_config_id   = var.create_maintenance_configuration ? azurerm_maintenance_configuration.patch_maintenance[0].id : null
    resource_group_name     = var.resource_group_name
    location               = var.location
  }
}

# Tags
output "tags" {
  description = "Tags applied to the Automation Account"
  value       = azurerm_automation_account.automation_account.tags
}