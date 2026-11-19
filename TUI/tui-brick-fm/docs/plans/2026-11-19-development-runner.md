# Development Runner Implementation Plan

> Execute the scoped script changes inline with test-driven development and verify the complete workspace before completion.

**Goal:** Make Bash and native PowerShell runners support formatting, linting, building, testing, and running hfm.

**Architecture:** Keep command orchestration and external tool execution in `scripts/`. Use the existing Stack workspace, stylish-haskell configuration, HLint, and the `hfm-dev-tools` architecture executable.

**Tech Stack:** Bash, Windows PowerShell 5.1 compatible PowerShell, Hspec, Stack, stylish-haskell, HLint.

**Spec:** The user requests `scripts/run.sh` and `scripts/run.ps1` to format, lint, build, test, and run the current codebase.

## Constraints

- Support `format`, `lint`, `build`, `test`, `run`, `all`, `clean`, and `help`.
- Default to `all`: format, lint, build, architecture checks, Stack tests, then run.
- Preserve separate commands and at most two starting directories for `run` and `all`.
- Resolve starting directories from the caller's location and invoke tools from the project root.
- Format and lint source files in workspace source and test directories, excluding build caches.
- Check required tools before modifying source files and stop on the first failed command, preserving its exit code.
- Keep PowerShell native and add no explanatory source comments.
- Preserve existing user changes and work in the supplied workspace; do not commit or change branches.

## Review Focus

- A repository or starting directory with spaces, Korean characters, or wildcard characters must retain its literal path.
- Generated Haskell files in build directories must not be formatted or linted.
- Missing tools and failures at every pipeline stage must prevent subsequent commands.
- Help and individual commands must require only their own dependencies.
- PowerShell must restore the caller's location.

## Task 1: Extend and verify both runners

**Files:** `scripts/run.sh`, `scripts/run.ps1`, `scripts/test-run-scripts.sh`, `scripts/test-powershell.ps1`, `.stylish-haskell.yaml`, `README.md`.

**Verification finding:** stylish-haskell 0.15.1.0's configured `module_header` step fails on implicit Main modules. Remove that step and add an integration regression test; retain the remaining formatting rules.

- [x] Add deterministic subprocess tests with external tool doubles for source selection, ordering, paths, validation, defaults, and failure propagation.
- [x] Run the new tests and confirm failures identify missing runner behavior.
- [x] Extend both runners using the existing formatter, linter, build system, and architecture checks.
- [x] Update PowerShell regression expectations and document usage and required tools.
- [x] Run Bash and PowerShell regression tests, actual formatter and linter commands, Stack tests, architecture checks, and terminal execution checks.
- [x] Review the final diff and report validation results and environment limitations.

## Validation

- Ten Bash runner and formatter configuration tests pass.
- PowerShell runner regressions pass with PowerShell 7.7.0 on Linux ARM64; native Windows PowerShell 5.1 and Windows installer checks require a Windows host.
- Actual formatting succeeds and is idempotent for all 44 Haskell files in a disposable copy.
- `scripts/run.sh build` and `scripts/run.sh test` pass, including the Haskell examples and architecture checks.
- The terminal keybinding suite passes; `scripts/run.sh run` opens the real TUI and exits successfully with `C-x C-c`.
- `scripts/run.sh lint` reports the same 17 preexisting HLint hints as the baseline and returns exit code 1. Consequently, `all` stops at lint until those hints are resolved.
- Source-discovery failure cleanup and preservation of the original exit code have a dedicated regression test.
- Independent read-only review found no remaining issues; `bash -n` and `git diff --check` pass.
