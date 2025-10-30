# Update Management Module
# This module links VMs to Azure Update Management and configures patch deployment
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

# Link Log Analytics workspace to Automation Account for Update Management
resource "azurerm_log_analytics_linked_service" "update_management" {
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  read_access_id      = var.automation_account_id
}

# VM extension for Azure Monitor Agent (replaces legacy MMA)
resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  for_each = var.virtual_machine_ids

  name                       = "${each.key}-ama"
  virtual_machine_id         = each.value
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    workspaceId = var.log_analytics_workspace_customer_id
  })

  protected_settings = jsonencode({
    workspaceKey = var.log_analytics_workspace_key
  })

  tags = merge(var.tags, {
    Module    = "update_management"
    Component = "monitor_agent"
  })
}

# Data collection rule association for Update Management
resource "azurerm_monitor_data_collection_rule_association" "update_management" {
  for_each = var.enable_data_collection_rule_association ? var.virtual_machine_ids : {}

  name                    = "${each.key}-dcr-association"
  target_resource_id      = each.value
  data_collection_rule_id = var.data_collection_rule_id
  description             = "Update Management data collection rule association for ${each.key}"
}

# Maintenance configuration assignment to VMs
resource "azurerm_maintenance_assignment_virtual_machine" "patch_assignment" {
  for_each = var.maintenance_configuration_id != null ? var.virtual_machine_ids : {}

  location                     = var.location
  maintenance_configuration_id = var.maintenance_configuration_id
  virtual_machine_id          = each.value
}

# Create VM tags for Update Management grouping
resource "azurerm_virtual_machine_extension" "update_management_tags" {
  for_each = var.configure_vm_tags ? var.virtual_machine_ids : {}

  name                 = "${each.key}-update-tags"
  virtual_machine_id   = each.value
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(templatefile("${path.module}/scripts/configure-tags.sh", {
      patch_group    = var.patch_group_tag
      environment    = var.environment_tag
      schedule       = var.schedule_tag
      maintenance_window = var.maintenance_window_tag
    }))
  })

  tags = merge(var.tags, {
    Module    = "update_management"
    Component = "tagging_script"
  })

  lifecycle {
    ignore_changes = [settings]
  }
}

# Update Management configuration script
resource "azurerm_virtual_machine_extension" "update_management_config" {
  for_each = var.configure_update_management ? var.virtual_machine_ids : {}

  name                 = "${each.key}-update-config"
  virtual_machine_id   = each.value
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(file("${path.module}/scripts/configure-update-management.sh"))
  })

  protected_settings = jsonencode({
    commandToExecute = "./configure-update-management.sh '${var.log_analytics_workspace_customer_id}' '${var.log_analytics_workspace_key}'"
  })

  tags = merge(var.tags, {
    Module    = "update_management"
    Component = "configuration_script"
  })

  depends_on = [
    azurerm_virtual_machine_extension.azure_monitor_agent,
    azurerm_log_analytics_linked_service.update_management
  ]
}

# Resource tags for Update Management organization
resource "azurerm_resource_group_template_deployment" "vm_tags_update" {
  count = var.apply_vm_tags_via_arm ? 1 : 0

  name                = "update-management-vm-tags-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    "contentVersion" = "1.0.0.0"
    "parameters" = {
      "virtualMachines" = {
        "type" = "array"
        "defaultValue" = [
          for vm_name, vm_id in var.virtual_machine_ids : {
            name = vm_name
            id   = vm_id
          }
        ]
      }
      "updateManagementTags" = {
        "type" = "object"
        "defaultValue" = {
          "PatchGroup"         = var.patch_group_tag
          "UpdateSchedule"     = var.schedule_tag
          "MaintenanceWindow" = var.maintenance_window_tag
          "UpdateManagement"   = "Enabled"
          "Environment"        = var.environment_tag
        }
      }
    }
    "variables" = {}
    "resources" = [
      {
        "type" = "Microsoft.Compute/virtualMachines"
        "apiVersion" = "2021-07-01"
        "name" = "[parameters('virtualMachines')[copyIndex()].name]"
        "location" = var.location
        "copy" = {
          "name" = "vmTagLoop"
          "count" = "[length(parameters('virtualMachines'))]"
        }
        "tags" = "[parameters('updateManagementTags')]"
        "properties" = {}
      }
    ]
    "outputs" = {
      "taggedVMs" = {
        "type" = "array"
        "value" = "[parameters('virtualMachines')]"
      }
    }
  })

  lifecycle {
    ignore_changes = [name]
  }
}

# Create Update Management schedules via REST API calls
resource "azurerm_resource_group_template_deployment" "update_schedules" {
  count = var.create_update_schedules ? 1 : 0

  name                = "update-schedules-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    "contentVersion" = "1.0.0.0"
    "parameters" = {
      "automationAccountName" = {
        "type" = "string"
        "defaultValue" = var.automation_account_name
      }
      "scheduleConfigurations" = {
        "type" = "array"
        "defaultValue" = var.update_schedules
      }
    }
    "variables" = {
      "updateManagementApiVersion" = "2020-01-13-preview"
    }
    "resources" = [
      {
        "type" = "Microsoft.Automation/automationAccounts/softwareUpdateConfigurations"
        "apiVersion" = "[variables('updateManagementApiVersion')]"
        "name" = "[concat(parameters('automationAccountName'), '/', parameters('scheduleConfigurations')[copyIndex()].name)]"
        "copy" = {
          "name" = "scheduleLoop"
          "count" = "[length(parameters('scheduleConfigurations'))]"
        }
        "properties" = {
          "updateConfiguration" = {
            "operatingSystem" = "Linux"
            "linux" = {
              "includedPackageClassifications" = "[parameters('scheduleConfigurations')[copyIndex()].includedClassifications]"
              "excludedPackageNameMasks" = "[parameters('scheduleConfigurations')[copyIndex()].excludedPackages]"
              "includedPackageNameMasks" = "[parameters('scheduleConfigurations')[copyIndex()].includedPackages]"
              "rebootSetting" = "[parameters('scheduleConfigurations')[copyIndex()].rebootSetting]"
            }
            "targets" = {
              "azureQueries" = [
                {
                  "scope" = [
                    "[subscription().id]"
                  ]
                  "tagSettings" = {
                    "tags" = "[parameters('scheduleConfigurations')[copyIndex()].targetTags]"
                    "filterOperator" = "All"
                  }
                  "locations" = []
                }
              ]
            }
            "duration" = "[parameters('scheduleConfigurations')[copyIndex()].duration]"
          }
          "scheduleInfo" = {
            "frequency" = "[parameters('scheduleConfigurations')[copyIndex()].frequency]"
            "startTime" = "[parameters('scheduleConfigurations')[copyIndex()].startTime]"
            "timeZone" = "[parameters('scheduleConfigurations')[copyIndex()].timeZone]"
            "interval" = "[parameters('scheduleConfigurations')[copyIndex()].interval]"
          }
        }
      }
    ]
  })

  lifecycle {
    ignore_changes = [name]
  }
}