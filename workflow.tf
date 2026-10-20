variable "userApiKey" {
  type      = string
  sensitive = true
}

# Runs NRQL and records the IncidentTiming event whenever a needle issue closes.
resource "newrelic_workflow_automation" "incident_timing" {
  name       = "incident_timing"
  scope_id   = var.accountId
  scope_type = "ACCOUNT"
  # file() + replace() rather than templatefile(): the YAML's ${{ }} expressions clash with Terraform interpolation.
  # jsonencode gives a quoted string that is also valid YAML.
  definition = replace(
    replace(
      replace(
        file("${path.module}/workflows/incident_timing.yaml"),
        "\"__SEARCH_TERM__\"",
        jsonencode(var.searchTerm)
      ),
      "\"__ACCOUNT_ID__\"",
      tostring(tonumber(var.accountId))
    ),
    "__AGGREGATION_WINDOW_MS__",
    tostring(var.aggregationWindow * 1000)
  )
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

  # Channel properties are passed to the automation as workflow inputs, matched by name (a "payload" property
  # was rejected as an undefined input). Values may use notification variables. accountId is not sent: it
  # defaults to the Terraform accountId in the automation.
  property {
    key   = "issueId"
    value = "{{issueId}}"
  }
}

resource "newrelic_workflow" "incident_timing" {
  name                  = "Needle issue closed - incident timing"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "needle policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.needle.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.incident_timing.id
    # ACTIVATED is mandatory for WORKFLOW_AUTOMATION; the automation exits unless the issue is closed
    notification_triggers = ["ACTIVATED", "CLOSED"]
  }
}
