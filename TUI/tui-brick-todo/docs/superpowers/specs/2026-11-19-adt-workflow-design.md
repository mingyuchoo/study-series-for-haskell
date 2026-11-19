# ADT workflow design

Refactor the todo application into a pure state machine while preserving key bindings, localization, SQLite schema, status cycling, and field normalization.

## Architecture

`tto-domain` depends only on base and owns validated todo fields and typed status transitions. `tto-application` depends on domain and owns workflow state, events, commands, results, and the repository port. The terminal adapter package `tto` implements SQLite and Brick integration. `apps/tto/Main.hs` composes dependencies.

## Approaches

Extending the existing UI Mode type would leave persistence decisions and invalid mode/index combinations in Brick handlers. A pure reducer with explicit commands covers the full workflow and permits deterministic tests; this is the selected engineering approach. A type-indexed GADT for every UI event would complicate runtime event dispatch without improving the closed ADT state model.

## State and effects

States cover startup, loading, browsing, creation, editing, pending repository operations, recoverable failures, and termination. An editing state carries its target and form together. A pending state carries the operation and recovery context. Results are accepted only for the matching operation and target. Selection uses stable todo IDs rather than saved list indexes.

The reducer emits commands. An application interpreter calls an abstract repository and returns an event. SQLite implements the repository with transactions so writes and their readback succeed together. Unknown stored statuses, missing rows, stale status updates, validation errors, and synchronous IO failures produce explicit errors. Asynchronous exceptions propagate.

Failed saves retain the original form for correction/retry; cancel returns to browsing without a write. Blank required actions fail validation in both create and edit. Tab cycles four fields. Navigation clamps at list boundaries. Termination ignores further events.

Configuration, localization, database resource acquisition, and release tooling remain infrastructure concerns. Startup todo loading passes through the same workflow as subsequent operations.

## Validation

Keep existing status, database, configuration, localization, and drawing tests. Add pure domain/workflow transition tests and integration tests against in-memory SQLite, including rollback and failure recovery. Update run/release scripts and Docker paths for the workspace.
