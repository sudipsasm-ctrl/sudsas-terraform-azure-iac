# Variables for Azure Automation Account Module
# Variable definitions for automation configuration

variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{4,49}[a-zA-Z0-9]$", var.automation_account_name))
    error_message = "Automation account name must be 6-50 characters, start with letter, end with alphanumeric, contain only alphanumeric and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where the Automation Account will be deployed"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the Automation Account"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Free", "Basic"], var.sku_name)
    error_message = "SKU name must be either 'Free' or 'Basic'."
  }
}

# Patch Management Configuration
variable "create_patch_runbooks" {
  description = "Whether to create patch management runbooks"
  type        = bool
  default     = true
}

variable "create_patch_schedule" {
  description = "Whether to create a patch deployment schedule"
  type        = bool
  default     = true
}

variable "patch_schedule_name" {
  description = "Name of the patch deployment schedule"
  type        = string
  default     = "WeeklyPatchDeployment"
}

variable "patch_schedule_start_time" {
  description = "Start time for patch deployment schedule (ISO 8601 format)"
  type        = string
  default     = null
  validation {
    condition = var.patch_schedule_start_time == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+\\d{2}:\\d{2}|Z)$", var.patch_schedule_start_time))
    error_message = "Start time must be in ISO 8601 format (e.g., 2024-01-01T02:00:00+00:00)."
  }
}

variable "patch_schedule_days" {
  description = "Days of the week for patch deployment"
  type        = list(string)
  default     = ["Sunday"]
  validation {
    condition = alltrue([
      for day in var.patch_schedule_days : 
      contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], day)
    ])
    error_message = "Schedule days must be valid day names."
  }
}

variable "timezone" {
  description = "Timezone for schedules"
  type        = string
  default     = "UTC"
}

# Maintenance Configuration
variable "create_maintenance_configuration" {
  description = "Whether to create maintenance configuration for Update Management"
  type        = bool
  default     = true
}

variable "maintenance_window_start_time" {
  description = "Start time for maintenance window (ISO 8601 format)"
  type        = string
  default     = null
}

variable "maintenance_window_duration" {
  description = "Duration of maintenance window (e.g., 02:00)"
  type        = string
  default     = "02:00"
  validation {
    condition     = can(regex("^\\d{2}:\\d{2}$", var.maintenance_window_duration))
    error_message = "Maintenance window duration must be in HH:MM format."
  }
}

variable "linux_patch_classifications" {
  description = "Linux patch classifications to include"
  type        = list(string)
  default     = ["Critical", "Security", "Other"]
  validation {
    condition = alltrue([
      for classification in var.linux_patch_classifications :
      contains(["Critical", "Security", "Other"], classification)
    ])
    error_message = "Linux patch classifications must be Critical, Security, or Other."
  }
}

variable "linux_packages_to_exclude" {
  description = "Linux packages to exclude from patching"
  type        = list(string)
  default     = []
}

variable "linux_packages_to_include" {
  description = "Linux packages to include in patching (empty means all)"
  type        = list(string)
  default     = []
}

variable "reboot_setting" {
  description = "Reboot setting for patch deployment"
  type        = string
  default     = "IfRequired"
  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.reboot_setting)
    error_message = "Reboot setting must be IfRequired, Never, or Always."
  }
}

# Automation Modules
variable "install_az_modules" {
  description = "Whether to install Azure PowerShell modules"
  type        = bool
  default     = true
}

# Automation Variables and Configuration
variable "patch_group_name" {
  description = "Name of the patch group for VM organization"
  type        = string
  default     = "default"
}

variable "automation_credentials" {
  description = "Map of automation credentials to create"
  type = map(object({
    username    = string
    password    = string
    description = string
  }))
  default   = {}
  sensitive = true
}

# Webhooks
variable "create_patch_webhook" {
  description = "Whether to create a webhook for patch management"
  type        = bool
  default     = false
}

# Role Assignments
variable "assign_automation_contributor_role" {
  description = "Whether to assign Automation Contributor role to the managed identity"
  type        = bool
  default     = true
}

variable "assign_vm_contributor_role" {
  description = "Whether to assign Virtual Machine Contributor role to the managed identity"
  type        = bool
  default     = true
}

# Configuration
variable "local_authentication_enabled" {
  description = "Whether local authentication is enabled for the Automation Account"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled"
  type        = bool
  default     = true
}

variable "encryption" {
  description = "Encryption configuration for the Automation Account"
  type = object({
    key_vault_key_id   = optional(string)
    user_assigned_identity_id = optional(string)
  })
  default = null
}

# Hybrid Worker Configuration
variable "hybrid_worker_groups" {
  description = "Map of hybrid worker groups to create"
  type = map(object({
    name = string
  }))
  default = {}
}

# DSC Configuration
variable "dsc_configurations" {
  description = "Map of DSC configurations to create"
  type = map(object({
    content_uri  = string
    description  = optional(string)
    log_verbose  = optional(bool, true)
  }))
  default = {}
}

# Tagging and Environment
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

# Diagnostic Settings
variable "enable_diagnostic_settings" {
  description = "Whether to enable diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings"
  type        = string
  default     = null
}

variable "diagnostic_logs" {
  description = "List of diagnostic log categories to enable"
  type        = list(string)
  default     = ["JobLogs", "JobStreams", "DscNodeStatus"]
}

variable "diagnostic_metrics" {
  description = "List of diagnostic metrics to enable"
  type        = list(string)
  default     = ["AllMetrics"]
}