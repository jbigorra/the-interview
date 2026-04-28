# Delta for Assisted Apply

## ADDED Requirements

### Requirement: Adapter Pattern for ATS
The system MUST use an adapter pattern to handle site-specific form pre-filling for Greenhouse, Lever, and Ashby.

#### Scenario: Applying via Greenhouse
- GIVEN a job hosted on Greenhouse in the "Reviewed" state
- WHEN the user clicks "Apply with Assistant"
- THEN the system MUST invoke the Greenhouse adapter
- AND the adapter MUST parse the Greenhouse application form structure
- AND the system MUST return a payload or script to pre-fill the user's basic info (name, email, resume link) into the form

#### Scenario: Unsupported ATS
- GIVEN a job hosted on an unknown or unsupported ATS platform
- WHEN the user clicks "Apply with Assistant"
- THEN the system MUST fallback to opening the job URL in a new tab without pre-filling
- AND the system MUST log a metric for "unsupported ATS encountered"

### Requirement: Form Pre-filling Execution
The system SHOULD use a browser extension or client-side JavaScript injection (via a safe iframe or similar MVP mechanism) to execute the pre-filling.

#### Scenario: Successful pre-fill
- GIVEN a supported ATS job page
- WHEN the pre-fill payload is delivered to the client
- THEN the client-side script MUST map the user's profile data to the specific form fields
- AND the user MUST be able to manually review and submit the form