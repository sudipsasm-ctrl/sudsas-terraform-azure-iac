# Variables for Log Analytics Workspace Module
# Variable definitions for monitoring and logging configuration

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{2,61}[a-zA-Z0-9]$", var.workspace_name))
    error_message = "Workspace name must be 4-63 characters, start and end with alphanumeric, contain only alphanumeric and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where the workspace will be deployed"
  type        = string
}

variable "sku" {
  description = "SKU of the Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
  validation {
    condition = contains([
      "Free", "Standalone", "PerNode", "PerGB2018", "Premium", "CapacityReservation"
    ], var.sku)
    error_message = "SKU must be one of: Free, Standalone, PerNode, PerGB2018, Premium, CapacityReservation."
  }
}

variable "retention_in_days" {
  description = "Data retention period in days"
  type        = number
  default     = 30
  validation {
    condition = (var.retention_in_days >= 7 && var.retention_in_days <= 730) || var.retention_in_days == -1
    error_message = "Retention must be between 7-730 days, or -1 for unlimited retention."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = -1
  validation {
    condition     = var.daily_quota_gb >= -1 && var.daily_quota_gb <= 4000
    error_message = "Daily quota must be between -1 (unlimited) and 4000 GB."
  }
}

variable "reservation_capacity_in_gb_per_day" {
  description = "Capacity reservation in GB per day (for CapacityReservation SKU)"
  type        = number
  default     = null
  validation {
    condition = var.reservation_capacity_in_gb_per_day == null || (
      var.reservation_capacity_in_gb_per_day >= 100 && var.reservation_capacity_in_gb_per_day <= 5000 &&
      var.reservation_capacity_in_gb_per_day % 100 == 0
    )
    error_message = "Reservation capacity must be between 100-5000 GB in 100 GB increments."
  }
}

# Configuration
variable "internet_ingestion_enabled" {
  description = "Whether internet ingestion is enabled"
  type        = bool
  default     = true
}

variable "internet_query_enabled" {
  description = "Whether internet queries are enabled"
  type        = bool
  default     = true
}

variable "local_authentication_disabled" {
  description = "Whether local authentication is disabled"
  type        = bool
  default     = false
}

# Solutions Configuration
variable "solutions" {
  description = "Map of Log Analytics solutions to install"
  type = map(object({
    publisher = string
    product   = string
  }))
  default = {
    "VMInsights" = {
      publisher = "Microsoft"
      product   = "OMSGallery/VMInsights"
    }
    "Updates" = {
      publisher = "Microsoft"
      product   = "OMSGallery/Updates"
    }
    "Security" = {
      publisher = "Microsoft"
      product   = "OMSGallery/Security"
    }
    "SecurityCenterFree" = {
      publisher = "Microsoft"
      product   = "OMSGallery/SecurityCenterFree"
    }
  }
}

# Saved Searches Configuration
variable "saved_searches" {
  description = "Map of saved searches to create"
  type = map(object({
    category      = string
    display_name  = string
    query         = string
    function_alias = optional(object({
      name                = string
      function_parameters = optional(string)
    }))
  }))
  default = {
    "Failed_SSH_Logins" = {
      category     = "Security"
      display_name = "Failed SSH Login Attempts"
      query        = "Syslog | where Facility == 'auth' and SeverityLevel == 'err' and SyslogMessage contains 'Failed password' | summarize count() by Computer, bin(TimeGenerated, 1h)"
    }
    "High_CPU_Usage" = {
      category     = "Performance"
      display_name = "High CPU Usage"
      query        = "Perf | where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total' | where CounterValue > 80 | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)"
    }
    "Disk_Space_Usage" = {
      category     = "Performance"
      display_name = "Low Disk Space"
      query        = "Perf | where ObjectName == 'Logical Disk' and CounterName == '% Free Space' | where CounterValue < 10 | summarize min(CounterValue) by Computer, InstanceName, bin(TimeGenerated, 1h)"
    }
  }
}

# Data Collection Configuration
variable "create_data_collection_rule" {
  description = "Whether to create a data collection rule"
  type        = bool
  default     = true
}

variable "collect_syslog_data" {
  description = "Whether to collect syslog data"
  type        = bool
  default     = true
}

variable "collect_performance_data" {
  description = "Whether to collect performance counter data"
  type        = bool
  default     = true
}

variable "syslog_facilities" {
  description = "List of syslog facilities to collect"
  type        = list(string)
  default     = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
  validation {
    condition = alltrue([
      for facility in var.syslog_facilities :
      contains(["auth", "authpriv", "cron", "daemon", "kern", "lpr", "mail", "mark", "news", "syslog", "user", "uucp", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"], facility)
    ])
    error_message = "Invalid syslog facility specified."
  }
}

variable "syslog_levels" {
  description = "List of syslog levels to collect"
  type        = list(string)
  default     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
  validation {
    condition = alltrue([
      for level in var.syslog_levels :
      contains(["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"], level)
    ])
    error_message = "Invalid syslog level specified."
  }
}

variable "performance_counters" {
  description = "List of performance counters to collect"
  type        = list(string)
  default = [
    "\\Processor(_Total)\\% Processor Time",
    "\\Memory\\Available MBytes",
    "\\Memory\\% Used Memory",
    "\\Logical Disk(_Total)\\% Free Space",
    "\\Logical Disk(_Total)\\Free Megabytes",
    "\\Network Interface(*)\\Bytes Total/sec"
  ]
}

variable "performance_counter_sampling_frequency" {
  description = "Performance counter sampling frequency in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.performance_counter_sampling_frequency >= 10 && var.performance_counter_sampling_frequency <= 1800
    error_message = "Sampling frequency must be between 10 and 1800 seconds."
  }
}

# Query Pack Configuration
variable "create_custom_query_pack" {
  description = "Whether to create a custom query pack"
  type        = bool
  default     = false
}

# Alerting Configuration
variable "action_groups" {
  description = "Map of action groups for alerting"
  type = map(object({
    short_name = string
    email_receivers = optional(list(object({
      name          = string
      email_address = string
    })), [])
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    webhook_receivers = optional(list(object({
      name                    = string
      service_uri            = string
      use_common_alert_schema = optional(bool, true)
    })), [])
  }))
  default = {}
}

variable "metric_alerts" {
  description = "Map of metric alerts to create"
  type = map(object({
    scopes            = list(string)
    description       = string
    severity          = number
    frequency         = optional(string, "PT1M")
    window_size       = optional(string, "PT5M")
    enabled           = optional(bool, true)
    action_group_key  = string
    criteria = object({
      metric_namespace = string
      metric_name     = string
      aggregation     = string
      operator        = string
      threshold       = number
    })
  }))
  default = {}
  validation {
    condition = alltrue([
      for alert_name, alert in var.metric_alerts :
      alert.severity >= 0 && alert.severity <= 4
    ])
    error_message = "Alert severity must be between 0 (Critical) and 4 (Verbose)."
  }
}

variable "log_alerts" {
  description = "Map of log search alerts to create"
  type = map(object({
    evaluation_frequency = string
    window_duration     = string
    severity            = number
    enabled             = optional(bool, true)
    description         = string
    action_group_key    = string
    criteria = object({
      query                   = string
      time_aggregation_method = string
      threshold              = number
      operator               = string
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })), [])
    })
  }))
  default = {}
}

# Diagnostic Settings
variable "enable_workspace_diagnostics" {
  description = "Whether to enable diagnostic settings for the workspace itself"
  type        = bool
  default     = false
}

variable "diagnostic_log_categories" {
  description = "List of diagnostic log categories to enable"
  type        = list(string)
  default     = ["Audit", "Operational"]
}

variable "diagnostic_metric_categories" {
  description = "List of diagnostic metric categories to enable"
  type        = list(string)
  default     = ["AllMetrics"]
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