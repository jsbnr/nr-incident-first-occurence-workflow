# First occurence automated workflow
This POC provides an example of a New Relic automated workflow that can discover the first occurence of an incident detected by a large aggregation window alert condition.

The probem this solves is where large aggregation windows hide the actual first occurence time of an incident. For example if the aggregation window is 1 hour and the threshold is "alert if {term} found in Log at least x times in 1 hour"  then the first occurence can only be roughly detected by looking up the start of the aggregation window in which the first occurence happened. For large aggregation windows this leads to reduced accuracy in the data. 

The solution exemplified in this project is to use an automated workflow that is triggered when an issue closes. The workflow interrogates the issue for the child incident ID's then for each incident it queries NRDB (data at rest) using a query similar to that in the condition to identify the exact time of the first offending data point within the time window of the incident lifecycle.


When incident closes
    For each incident in the issue
        Get degradationTime and incidentOpenTime from incident
        Query Log for window degradationTime to incidentOpenTime for first occurence of search term
        Record data to NRDB 

A flow chart of the operation can be found here: [flow.md](flow.md)

## Installation
Make sure terraform is installed. I recommend [tfenv](https://github.com/tfutils/tfenv) for managing your terraform binaries.

Update the `runtf.sh.sample` file with your credentials and accont details and rename it `runtf.sh`. **Important do not commit this new file to git!** (It should be ignored in `.gitignore` already)

Note: You may want to update the version numbers in [main.tf](main.tf) to the latest versions of  Terraform and the New Relic provider.

## Initialisation
Use the `runtf.sh` helper script where ever you would normally run `terraform`. It simply wraps the terraform with some environment variables that make it easier to switch between projects.

First initialise terraform:
```
./runtf.sh init
```

Now apply the changes which will install a alert condition and workflow:
```
./runtf.sh apply
```

## Testing
Test by running the send_log.sh script to send sample data to your account. (the default term detected by the alert condition is "needle")

e.g.: `./send_log.sh your_ingest_key "find the needle in the haystack"`

## Querying data
You can query the output of the workflow in NRQL: `FROM IncidentTiming select *`

Attributes of interest in the IncdentTiming custom event:
- incidentId / issueId - the ID of the incident/issue
- degradationTime - the degradation time reported by the alrts system (snapped to an aggrgeation window start time)
- openTime - the time the incident was actually created
- firstOccurenceTime - the earliest time the term was found within the incident timeframe
- timeToDetectMs - the time it took from the first occurence to incident opening.
