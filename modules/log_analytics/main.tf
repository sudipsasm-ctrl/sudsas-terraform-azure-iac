# Log Analytics Workspace Module
# This module creates Azure Log Analytics workspace for monitoring and logging
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

# Create the Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                = var.sku
  retention_in_days  = var.retention_in_days
  daily_quota_gb     = var.daily_quota_gb

  # Advanced settings
  internet_ingestion_enabled = var.internet_ingestion_enabled
  internet_query_enabled     = var.internet_query_enabled
  reservation_capacity_in_gb_per_day = var.reservation_capacity_in_gb_per_day
  local_authentication_disabled = var.local_authentication_disabled

  tags = merge(var.tags, {
    Module      = "log_analytics"
    Environment = var.environment
  })
}

# Create Log Analytics Solutions
resource "azurerm_log_analytics_solution" "solutions" {
  for_each = var.solutions

  solution_name         = each.key
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = each.value.publisher
    product   = each.value.product
  }

  tags = merge(var.tags, {
    Module   = "log_analytics"
    Solution = each.key
  })

  depends_on = [azurerm_log_analytics_workspace.workspace]
}

# Create custom tables for specific data collection
resource "azurerm_log_analytics_query_pack" "custom_queries" {
  count               = var.create_custom_query_pack ? 1 : 0
  name                = "${var.workspace_name}-queries"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.tags, {
    Module    = "log_analytics"
    Component = "query_pack"
  })
}

# Saved searches for common queries
resource "azurerm_log_analytics_saved_search" "common_searches" {
  for_each = var.saved_searches

  name                       = each.key
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
  category                   = each.value.category
  display_name               = each.value.display_name
  query                      = each.value.query

  dynamic "function_alias" {
    for_each = lookup(each.value, "function_alias", null) != null ? [each.value.function_alias] : []
    content {
      name                 = function_alias.value.name
      function_parameters  = lookup(function_alias.value, "function_parameters", null)
    }
  }

  tags = merge(var.tags, {
    Module = "log_analytics"
    Type   = "saved_search"
  })

  depends_on = [azurerm_log_analytics_workspace.workspace]
}

# Data collection rules for Azure Monitor Agent
resource "azurerm_monitor_data_collection_rule" "dcr" {
  count               = var.create_data_collection_rule ? 1 : 0
  name                = "${var.workspace_name}-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
      name                  = "log-analytics-destination"
    }
  }

  # Syslog data collection
  dynamic "data_flow" {
    for_each = var.collect_syslog_data ? [1] : []
    content {
      streams      = ["Microsoft-Syslog"]
      destinations = ["log-analytics-destination"]
    }
  }

  # Performance counter data collection
  dynamic "data_flow" {
    for_each = var.collect_performance_data ? [1] : []
    content {
      streams      = ["Microsoft-Perf"]
      destinations = ["log-analytics-destination"]
    }
  }

  # Syslog data sources
  dynamic "data_sources" {
    for_each = var.collect_syslog_data ? [1] : []
    content {
      syslog {
        facility_names = var.syslog_facilities
        log_levels     = var.syslog_levels
        name           = "syslog-datasource"
      }
    }
  }

  # Performance counter data sources
  dynamic "data_sources" {
    for_each = var.collect_performance_data ? [1] : []
    content {
      performance_counter {
        streams                       = ["Microsoft-Perf"]
        sampling_frequency_in_seconds = var.performance_counter_sampling_frequency
        counter_specifiers           = var.performance_counters
        name                         = "perf-datasource"
      }
    }
  }

  tags = merge(var.tags, {
    Module    = "log_analytics"
    Component = "data_collection_rule"
  })

  depends_on = [azurerm_log_analytics_workspace.workspace]
}

# Action groups for alerting
resource "azurerm_monitor_action_group" "action_groups" {
  for_each = var.action_groups

  name                = each.key
  resource_group_name = var.resource_group_name
  short_name         = each.value.short_name

  # Email receivers
  dynamic "email_receiver" {
    for_each = lookup(each.value, "email_receivers", [])
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }

  # SMS receivers
  dynamic "sms_receiver" {
    for_each = lookup(each.value, "sms_receivers", [])
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  # Webhook receivers
  dynamic "webhook_receiver" {
    for_each = lookup(each.value, "webhook_receivers", [])
    content {
      name                    = webhook_receiver.value.name
      service_uri            = webhook_receiver.value.service_uri
      use_common_alert_schema = lookup(webhook_receiver.value, "use_common_alert_schema", true)
    }
  }

  tags = merge(var.tags, {
    Module    = "log_analytics"
    Component = "action_group"
  })
}

# Metric alerts
resource "azurerm_monitor_metric_alert" "metric_alerts" {
  for_each = var.metric_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  scopes              = each.value.scopes
  description         = each.value.description
  enabled             = lookup(each.value, "enabled", true)
  severity           = each.value.severity
  frequency          = lookup(each.value, "frequency", "PT1M")
  window_size        = lookup(each.value, "window_size", "PT5M")

  criteria {
    metric_namespace = each.value.criteria.metric_namespace
    metric_name     = each.value.criteria.metric_name
    aggregation     = each.value.criteria.aggregation
    operator        = each.value.criteria.operator
    threshold       = each.value.criteria.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.action_groups[each.value.action_group_key].id
  }

  tags = merge(var.tags, {
    Module    = "log_analytics"
    Component = "metric_alert"
  })

  depends_on = [azurerm_monitor_action_group.action_groups]
}

# Log search alerts
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "log_alerts" {
  for_each = var.log_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  location            = var.location
  
  evaluation_frequency = each.value.evaluation_frequency
  window_duration     = each.value.window_duration
  scopes              = [azurerm_log_analytics_workspace.workspace.id]
  severity           = each.value.severity
  enabled            = lookup(each.value, "enabled", true)
  description        = each.value.description

  criteria {
    query                   = each.value.criteria.query
    time_aggregation_method = each.value.criteria.time_aggregation_method
    threshold              = each.value.criteria.threshold
    operator               = each.value.criteria.operator

    dynamic "dimension" {
      for_each = lookup(each.value.criteria, "dimensions", [])
      content {
        name     = dimension.value.name
        operator = dimension.value.operator
        values   = dimension.value.values
      }
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.action_groups[each.value.action_group_key].id]
  }

  tags = merge(var.tags, {
    Module    = "log_analytics"
    Component = "log_alert"
  })

  depends_on = [
    azurerm_log_analytics_workspace.workspace,
    azurerm_monitor_action_group.action_groups
  ]
}

# Diagnostic settings for the workspace itself
resource "azurerm_monitor_diagnostic_setting" "workspace_diagnostics" {
  count                      = var.enable_workspace_diagnostics ? 1 : 0
  name                       = "${var.workspace_name}-diagnostics"
  target_resource_id         = azurerm_log_analytics_workspace.workspace.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id

  dynamic "enabled_log" {
    for_each = var.diagnostic_log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = var.diagnostic_metric_categories
    content {
      category = metric.value
      enabled  = true
    }
  }
}