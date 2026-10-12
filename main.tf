variable "accountId" { type = string }


resource "newrelic_alert_policy" "piglet" {
  name                = "Piglet log alerts"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "piglet_logs" {
  account_id = var.accountId
  policy_id  = newrelic_alert_policy.piglet.id
  type       = "static"
  name       = "Piglet appears in logs"
  enabled    = true

  nrql {
    query = "SELECT count(*) FROM Log WHERE message LIKE '%piglet%'"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = 5
    threshold_duration    = 900
    threshold_occurrences = "all"
  }

  aggregation_window           = 900
  aggregation_method           = "EVENT_FLOW"
  aggregation_delay            = 120
  violation_time_limit_seconds = 86400
}
