variable "accountId" { type = string }

variable "searchTerm" {
  type        = string
  default     = "needle"
  description = "Term matched in Log.message by the alert condition and by the incident_timing automation."

  validation {
    condition     = length(var.searchTerm) > 0 && !can(regex("['\\\\]", var.searchTerm))
    error_message = "searchTerm must be non-empty and must not contain a single quote or backslash."
  }
}

variable "threshold" {
  type        = number
  default     = 5
  description = "Alert fires when the matching log count is above this value."
}

variable "aggregationWindow" {
  type        = number
  default     = 300
  description = "Alert aggregation window in seconds."
}

variable "thresholdDuration" {
  type        = number
  default     = 300
  description = "Alert threshold duration in seconds. Must be a multiple of aggregationWindow."

  validation {
    condition     = var.thresholdDuration % var.aggregationWindow == 0
    error_message = "thresholdDuration must be a multiple of aggregationWindow."
  }
}

variable "thresholdOccurrences" {
  type        = string
  default     = "at_least_once"
  description = "\"all\" = 'for at least <duration>', \"at_least_once\" = 'at least once in <duration>'."

  validation {
    condition     = contains(["all", "at_least_once"], lower(var.thresholdOccurrences))
    error_message = "thresholdOccurrences must be \"all\" or \"at_least_once\"."
  }
}

resource "newrelic_alert_policy" "needle" {
  name                = "Needle log alerts"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "needle_logs" {
  account_id = var.accountId
  policy_id  = newrelic_alert_policy.needle.id
  type       = "static"
  name       = "Needle appears in logs"
  enabled    = true

  nrql {
    query = "SELECT count(*) FROM Log WHERE message LIKE '%${var.searchTerm}%'"
  }

  critical {
    operator              = "above"
    threshold             = var.threshold
    threshold_duration    = var.thresholdDuration
    threshold_occurrences = lower(var.thresholdOccurrences)
  }

  aggregation_window           = var.aggregationWindow
  aggregation_method           = "EVENT_TIMER"
  aggregation_timer            = 60
  violation_time_limit_seconds = 86400

  # count(*) over no matching logs returns no data rather than 0, so the incident never recovers on its own.
  # Closing on loss of signal ends it once no matching logs have arrived for one aggregation window.
  expiration_duration            = var.aggregationWindow
  close_violations_on_expiration = true
}
