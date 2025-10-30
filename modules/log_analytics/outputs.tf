# Outputs for Log Analytics Workspace Module
# Provides comprehensive output information for integration with monitoring and automation

output "workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "workspace_name" {
  description = "The name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.name
}

output "workspace_location" {
  description = "The location of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.location
}

output "workspace_resource_group" {
  description = "The resource group of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.resource_group_name
}

output "workspace_customer_id" {
  description = "The workspace customer ID (used for agent configuration)"
  value       = azurerm_log_analytics_workspace.workspace.workspace_id
}

output "primary_shared_key" {
  description = "The primary shared key of the workspace"
  value       = azurerm_log_analytics_workspace.workspace.primary_shared_key
  sensitive   = true
}

output "secondary_shared_key" {
  description = "The secondary shared key of the workspace"
  value       = azurerm_log_analytics_workspace.workspace.secondary_shared_key
  sensitive   = true
}

# Workspace Configuration
output "workspace_sku" {
  description = "The SKU of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.sku
}

output "retention_in_days" {
  description = "The data retention period in days"
  value       = azurerm_log_analytics_workspace.workspace.retention_in_days
}

output "daily_quota_gb" {
  description = "The daily ingestion quota in GB"
  value       = azurerm_log_analytics_workspace.workspace.daily_quota_gb
}

# Solutions Information
output "installed_solutions" {
  description = "List of installed Log Analytics solutions"
  value       = keys(var.solutions)
}

output "solution_ids" {
  description = "Map of solution names to their IDs"
  value = {
    for solution_name, solution in azurerm_log_analytics_solution.solutions :
    solution_name => solution.id
  }
}

# Saved Searches Information
output "saved_searches" {
  description = "Map of saved search names to their details"
  value = {
    for search_name, search in azurerm_log_analytics_saved_search.common_searches :
    search_name => {
      id           = search.id
      category     = search.category
      display_name = search.display_name
    }
  }
}

output "saved_search_names" {
  description = "List of saved search names"
  value       = keys(var.saved_searches)
}

# Data Collection Rule Information
output "data_collection_rule_id" {
  description = "The ID of the data collection rule"
  value       = var.create_data_collection_rule ? azurerm_monitor_data_collection_rule.dcr[0].id : null
}

output "data_collection_rule_name" {
  description = "The name of the data collection rule"
  value       = var.create_data_collection_rule ? azurerm_monitor_data_collection_rule.dcr[0].name : null
}

# Action Groups Information
output "action_group_ids" {
  description = "Map of action group names to their IDs"
  value = {
    for group_name, group in azurerm_monitor_action_group.action_groups :
    group_name => group.id
  }
}

output "action_group_names" {
  description = "List of action group names"
  value       = keys(var.action_groups)
}

# Alerts Information
output "metric_alert_ids" {
  description = "Map of metric alert names to their IDs"
  value = {
    for alert_name, alert in azurerm_monitor_metric_alert.metric_alerts :
    alert_name => alert.id
  }
}

output "log_alert_ids" {
  description = "Map of log alert names to their IDs"
  value = {
    for alert_name, alert in azurerm_monitor_scheduled_query_rules_alert_v2.log_alerts :
    alert_name => alert.id
  }
}

output "configured_alerts" {
  description = "Summary of configured alerts"
  value = {
    metric_alerts = length(var.metric_alerts)
    log_alerts    = length(var.log_alerts)
  }
}

# Query Pack Information
output "query_pack_id" {
  description = "The ID of the custom query pack"
  value       = var.create_custom_query_pack ? azurerm_log_analytics_query_pack.custom_queries[0].id : null
}

# Connection Information for VM Integration
output "vm_connection_info" {
  description = "Information needed for connecting VMs to Log Analytics"
  value = {
    workspace_id         = azurerm_log_analytics_workspace.workspace.workspace_id
    workspace_name       = azurerm_log_analytics_workspace.workspace.name
    resource_id         = azurerm_log_analytics_workspace.workspace.id
    location            = azurerm_log_analytics_workspace.workspace.location
    resource_group_name = azurerm_log_analytics_workspace.workspace.resource_group_name
    data_collection_rule_id = var.create_data_collection_rule ? azurerm_monitor_data_collection_rule.dcr[0].id : null
  }
}

# Data Collection Configuration Summary
output "data_collection_configuration" {
  description = "Summary of data collection configuration"
  value = {
    syslog_collection_enabled    = var.collect_syslog_data
    performance_collection_enabled = var.collect_performance_data
    syslog_facilities           = var.syslog_facilities
    syslog_levels              = var.syslog_levels
    performance_counters       = var.performance_counters
    sampling_frequency         = var.performance_counter_sampling_frequency
  }
}

# Diagnostic Settings
output "diagnostic_settings_enabled" {
  description = "Whether diagnostic settings are enabled for the workspace"
  value       = var.enable_workspace_diagnostics
}

# Security and Access Information
output "access_configuration" {
  description = "Access configuration details"
  value = {
    internet_ingestion_enabled     = azurerm_log_analytics_workspace.workspace.internet_ingestion_enabled
    internet_query_enabled        = azurerm_log_analytics_workspace.workspace.internet_query_enabled
    local_authentication_disabled = azurerm_log_analytics_workspace.workspace.local_authentication_disabled
  }
}

# Capacity and Billing Information
output "billing_configuration" {
  description = "Billing and capacity configuration"
  value = {
    sku                          = azurerm_log_analytics_workspace.workspace.sku
    daily_quota_gb              = azurerm_log_analytics_workspace.workspace.daily_quota_gb
    retention_in_days           = azurerm_log_analytics_workspace.workspace.retention_in_days
    reservation_capacity_in_gb_per_day = var.reservation_capacity_in_gb_per_day
  }
}

# Monitoring Endpoints
output "monitoring_endpoints" {
  description = "Important endpoints for monitoring configuration"
  value = {
    portal_url = "https://portal.azure.com/#@/resource${azurerm_log_analytics_workspace.workspace.id}/overview"
    logs_url   = "https://portal.azure.com/#@/resource${azurerm_log_analytics_workspace.workspace.id}/logs"
  }
}

# Tags Information
output "tags" {
  description = "Tags applied to the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.workspace.tags
}

# Resource Dependencies
output "resource_dependencies" {
  description = "Information about resource dependencies for other modules"
  value = {
    workspace_resource_id       = azurerm_log_analytics_workspace.workspace.id
    data_collection_rule_resource_id = var.create_data_collection_rule ? azurerm_monitor_data_collection_rule.dcr[0].id : null
    primary_action_group_id     = length(azurerm_monitor_action_group.action_groups) > 0 ? values(azurerm_monitor_action_group.action_groups)[0].id : null
  }
}