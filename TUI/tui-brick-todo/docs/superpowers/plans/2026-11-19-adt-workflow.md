# ADT Workflow Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task.

**Goal:** Represent every interactive todo operation with explicit ADT states, events, and commands.

**Architecture:** Base-only domain, pure application reducer with abstract repository, Brick/SQLite adapters, and an executable composition root. Workspace dependencies point inward.

**Tech Stack:** Haskell, Stack/Hpack, Hspec, Brick, sqlite-simple.

**Spec:** docs/superpowers/specs/2026-11-19-adt-workflow-design.md

## Global Constraints

Preserve existing SQLite schema, localization files, configurable shortcuts, and status cycle. No source comments or cross-package relative imports. Domain depends only on base.

## Review Focus

Empty create/edit actions must not persist. Failed saves retain drafts. Invalid/out-of-phase results must not mutate state. Stale status changes and missing rows must fail explicitly. Write/readback failures roll back.

## Tasks

- [x] 1. Add failing domain/workflow tests; introduce domain and application workspace packages. Implement field validation, status cycle, and `transition :: Event -> Workflow -> (Workflow, [Command])`.
- [x] 2. Define `Repository m` and `runCommand`, add failing in-memory SQLite integration tests, then implement transactional repository and explicit boundary errors.
- [x] 3. Move terminal adapters and executable into packages/apps; replace procedural UI handlers with event translation, state projection, and command execution. Remove legacy service/interpreter paths.
- [x] 4. Update run/release/Docker paths and architecture documentation. Run all Haskell and release tests, formatting, lint, and a terminal smoke test. Review dependency boundaries and source comments.

## Execution record

Baseline: `stack test --fast` passed, 193 examples. Graft cannot index this project's Haskell modules; its query and caller lookup returned no usable Haskell nodes. Work directly in the requested checkout and preserve adjacent project changes. No commits or external publication requested.


Final verification:

- `stack test --fast`: domain 4, workflow 25, adapter 184; 213 examples, zero failures.
- Fourmolu check: passed for all workspace/application/test Haskell sources.
- `hlint apps packages test Setup.hs`: no hints.
- `python3 scripts/test_release.py -v`: Linux 10 passed; PowerShell 4 skipped because PowerShell is unavailable.
- Pseudo-terminal integration with a temporary SQLite database: create with four fields, edit, status cycle, failed-save draft preservation and retry, cancel, delete, quit passed. The harness linked with `-threaded` and used a 60-row terminal.
- External compilation probe confirms `TodoFields` cannot be forged through exported record labels.
- Shell syntax and `git diff --check`: passed.
- Existing partial-function warnings in `test/DBSpec.hs` remain unchanged.

Read-only independent review identified an exported-record update escape from validation and ignored-write acknowledgements. The domain now exposes accessor functions over an opaque positional constructor. Repository writes verify affected rows, deletes verify absence, and ignored insert/update/delete regression tests pass. No outstanding Critical or Important review issues remain. Settings/message file loading now lives in dedicated infrastructure modules.

Ruling: keep configuration/resource acquisition outside the workflow, as infrastructure composition. All interactive todo operations and startup loading use the ADT reducer. Keep the existing SQLite schema and status strings at the storage boundary. No commits, branches, publication, or modifications to neighboring projects were made.
