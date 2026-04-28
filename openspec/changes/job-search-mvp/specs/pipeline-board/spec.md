# Delta for Pipeline Board

## ADDED Requirements

### Requirement: Kanban Board UI
The system MUST display a Kanban board using Hotwire/Turbo and SortableJS with the following columns: New, Reviewed, Applied, Interview, Offer, Rejected.

#### Scenario: Viewing the board
- GIVEN an authenticated user with jobs in various states
- WHEN the user navigates to the pipeline dashboard
- THEN the system MUST display all columns
- AND each job MUST appear as a card in its respective column based on its state

### Requirement: State Management via Drag-and-Drop
The system MUST allow users to change a job's state by dragging its card between columns.

#### Scenario: Successful drag-and-drop
- GIVEN an authenticated user on the pipeline dashboard
- WHEN the user drags a job card from "New" to "Reviewed"
- THEN the UI MUST optimistically update the card's position
- AND SortableJS MUST trigger a Turbo Stream or standard Rails AJAX request to update the job's state in the database
- AND the system SHOULD broadcast the state change via Action Cable (Turbo Streams) to keep other active sessions in sync

#### Scenario: Failed drag-and-drop update
- GIVEN an authenticated user on the pipeline dashboard
- WHEN the user drags a job card to a new column
- AND the server request fails (e.g., validation error or network issue)
- THEN the UI MUST revert the card to its original column
- AND the system MUST display an error toast notification