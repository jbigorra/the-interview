# Delta for Profile Management

## ADDED Requirements

### Requirement: User Profile Data
The system MUST allow users to define a search profile containing job titles, required keywords, negative keywords (dealbreakers), and a minimum LLM match score threshold.

#### Scenario: Creating a valid profile
- GIVEN an authenticated user
- WHEN the user submits the profile form with valid role titles, keywords, and a threshold of 75
- THEN the system MUST save the Profile record
- AND the system MUST associate the Profile with the user

#### Scenario: Invalid threshold
- GIVEN an authenticated user
- WHEN the user submits the profile form with a threshold of 150
- THEN the system MUST reject the submission
- AND the system MUST display a validation error stating the threshold must be between 0 and 100