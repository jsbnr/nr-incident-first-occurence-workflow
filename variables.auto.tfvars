# Non-secret settings, loaded automatically by Terraform (*.auto.tfvars).
# accountId and userApiKey are not set here; runtf.sh supplies them.

# Term matched in Log.message by the alert condition and the incident_timing automation
searchTerm = "needle"

# Alert fires when the matching log count is above this value
threshold = 0

# Alert timing, in seconds. thresholdDuration must be a multiple of aggregationWindow.
aggregationWindow = 120
thresholdDuration = 120

# "at_least_once" = "at least once in <duration>", "all" = "for at least <duration>"
thresholdOccurrences = "all"
