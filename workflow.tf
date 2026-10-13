variable "userApiKey" {
  type      = string
  sensitive = true
}

# Runs NRQL and records the IncidentTiming event whenever a piglet issue closes.
resource "newrelic_workflow_automation" "incident_timing" {
  name       = "incident_timing"
  scope_id   = var.accountId
  scope_type = "ACCOUNT"
  definition = file("${path.module}/workflows/incident_timing.yaml")
}

resource "newrelic_notification_destination" "workflow_automation" {
  account_id = var.accountId
  name       = "Workflow Automation"
  type       = "WORKFLOW_AUTOMATION"

  # Required by the provider schema for every type; auth is the header below.
  property {
    key   = ""
    value = ""
  }

  auth_custom_header {
    key   = "Api-Key"
    value = var.userApiKey
  }
}

resource "newrelic_notification_channel" "incident_timing" {
  account_id     = var.accountId
  name           = "Incident timing automation"
  type           = "WORKFLOW_AUTOMATION"
  destination_id = newrelic_notification_destination.workflow_automation.id
  product        = "IINT"

  property {
    key   = "workflowAutomation"
    value = newrelic_workflow_automation.incident_timing.name
  }
}

resource "newrelic_workflow" "incident_timing" {
  name                  = "Piglet issue closed - incident timing"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "piglet policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.piglet.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.incident_timing.id
    # ACTIVATED is mandatory for WORKFLOW_AUTOMATION; the automation exits unless the issue is closed
    notification_triggers = ["ACTIVATED", "CLOSED"]
  }
}
