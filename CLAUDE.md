# poc-automated-workflow

Customer POC (EON): when a New Relic alert issue closes, work out how long it took to detect the problem and record it as a custom event. Terraform (newrelic provider ~> 3.100.4, Terraform ~> 1.16.5), local state.

## What it does

Alert condition: `count(*)` of `Log` where `message LIKE '%<searchTerm>%'` is above 5 (`main.tf`). "needle" is only a test value and the default of Terraform variable `searchTerm`, the single source for the term: it feeds the NRQL condition, and `workflow.tf` substitutes it for the `"__SEARCH_TERM__"` placeholder (the `defaultValue` of the automation's `searchTerm` input) via `replace(file(...))`. Do not hard-code the term in either place.

Alert tuning variables in `main.tf` (defaults match the current test setup): `aggregationWindow` (300s), `thresholdDuration` (300s, must be a multiple of the window), `thresholdOccurrences` (`at_least_once` = "at least once in", `all` = "for at least"). `searchTerm` rejects empty values, single quotes and backslashes because it is embedded in NRQL.

On issue close, for each incident in the issue, the automation writes an `IncidentTiming` event:

| attribute | source |
|---|---|
| `incidentId`, `issueId` | issue / incident |
| `degradationTime`, `openTime` | `NrAiIncident` (epoch ms, numeric) |
| `incidentOpenTime` | `earliest(timestamp)` of the `NrAiIncident` row with `event = 'open'` |
| `firstOccurrenceTime` | `earliest(timestamp)` of matching `Log` between `degradationTime` and `openTime` |
| `timeToDetectMs` | `incidentOpenTime - firstOccurrenceTime` (null if no log found) |

## Architecture

Alert condition -> policy `Needle log alerts` -> `newrelic_workflow` (filter `labels.policyIds` = policy id) -> `WORKFLOW_AUTOMATION` notification channel/destination -> `newrelic_workflow_automation` (`incident_timing`). No external compute.

- `main.tf`: alert variables, alert policy and NRQL condition (defaults of 300s for testing; originally 900).
- `workflow.tf`: automation, destination (auth via User API key header), channel, alert workflow.
- `workflows/incident_timing.yaml`: the automation definition, loaded with `file()` (not `templatefile`, because `${{ }}` clashes with Terraform interpolation).
- `send_log.sh <ingest-key> <message>`: sends a test log through the Log API.
- `runtf.sh` (gitignored, holds credentials): wraps terraform. `runtf.sh.sample` shows the vars: `accountId` and `userApiKey`. Run `./runtf.sh plan` / `apply`.
- Offline check: `NEW_RELIC_ACCOUNT_ID=1 NEW_RELIC_API_KEY=x terraform validate`. This does NOT parse the automation YAML; the API does that on apply.

## Automation flow (`incident_timing.yaml`)

`waitForClose` (1s) -> `getIssue` (NrAiIssue where `event = 'close'`; gets `incidentIds`) -> `onlyIfClosed` switch -> loop over incident IDs: `getIncident` -> `getFirstOccurrence` -> `recordTiming` (`newrelic.ingest.sendEvents`).

The destination forces `notification_triggers = ["ACTIVATED", "CLOSED"]` (ACTIVATED is mandatory). The activation run finds no close row and exits at `onlyIfClosed`; that is expected. The automation receives only `issueId` and `accountId`.

Each query has a `build...Query` (assign) step, a log before it runs, and a log after with results. Debug with:

```sql
FROM Log SELECT timestamp, message, step, incidentId, query, success, errorMessage, results
WHERE workflow = 'incident_timing' SINCE 30 minutes ago ORDER BY timestamp
```

## Hard-won facts (verified by runs)

- Workflow Automation jq is a limited engine: **no `strftime`, no `todate`**. `assign`, `as $x` bindings, `gsub`, `split`, `select`, `ascii_downcase`, `startswith` worked or are used; test unfamiliar functions with a real run.
- Large numbers (epoch ms) interpolated into a string render as `1.7917956E12` and NRQL rejects them. Fix: return them from NRQL as strings with `string(x, precision: 0)` (user confirmed plain digits) and interpolate those. Whole-value expressions keep numeric type, so the event still gets numbers.
- `description` in the YAML must match `^[A-Za-z0-9 _-]*$` (no commas). `name` must equal the Terraform resource `name`.
- A loop's `steps` go **inside** `for:` next to `in:`.
- `NrAiIssue` and `NrAiIncident` mark their lifecycle with the **`event`** attribute (`close`, `open`); there is no usable `state`/`status`. `NrAiIssue.incidentIds` is a single string (not an array), so it is split in jq; `uniques()` can't be used on it.
- **Never put the search term in a log `message`.** The alert counts `Log` messages containing it, so debug logs would feed the alert. Messages are static or mask the term (`<term>`); the real query goes in the `query` attribute.
- YAML: queries are `>-` block scalars so they can hold both quote types.

## Unverified / open

- `workflowAutomation` property on the channel is set to the automation name; docs only say "free text".
- Filter attribute `labels.policyIds` was a guess; confirm an alert-triggered activation run appears.
- `latest(string(degradationTime, precision: 0))` nesting was expected to work, pending a run.
- With a 5-minute alert window, the first matching log can precede `degradationTime`; the `SINCE` bound may need to move back by the aggregation window if `firstOccurrenceTime` is null or late.
- `waitForClose` is 1s; if close runs exit early because the close row hasn't landed, raise it.
- State holds the User API key (destination header) in plain text; fine for a POC only.

## Working style

Share a short plan and confirm direction before structural changes (user's global instruction). Do not apply Terraform or send data to New Relic without being asked.
