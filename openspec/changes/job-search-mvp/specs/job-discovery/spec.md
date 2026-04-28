# Delta for Job Discovery

## ADDED Requirements

### Requirement: Google Search Discovery
The system MUST query SerpApi to discover job postings on specific ATS portals (jobs.lever.co, boards.greenhouse.io, jobs.ashbyhq.com).

#### Scenario: Successful ATS discovery
- GIVEN a configured search profile with role keywords
- WHEN the daily background job runs
- THEN the system MUST construct a Google dork query targeting the supported ATS domains
- AND the system MUST fetch results via SerpApi
- AND the system MUST save unique job URLs as new Job records in "Discovered" state

#### Scenario: No new jobs found
- GIVEN a search profile
- WHEN the daily background job runs and SerpApi returns URLs already in the database
- THEN the system MUST NOT create duplicate Job records
- AND the system MUST log a successful run with 0 new discoveries

### Requirement: Search Frequency Limits
The system SHOULD NOT query SerpApi more than once per user profile per 24-hour period to manage costs.

#### Scenario: Duplicate run within 24 hours
- GIVEN a successful SerpApi run for a user at 10:00 AM
- WHEN a discovery job is triggered for the same user at 2:00 PM
- THEN the system MUST skip the SerpApi call
- AND the system MUST mark the job as completed without errors