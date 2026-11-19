# Remove the development tooling's interpreter dependency

**Goal:** Replace the four development scripts with Haskell or Bash while preserving their checks and removing their old runtime requirement.

**Architecture:** Add `hfm-dev-tools` to the existing Stack/Cabal workspace. Its architecture rules consume an immutable workspace snapshot; a separate filesystem adapter loads that snapshot. The architecture executable and Unix PTY executable use this package. Bash runner regression tests use isolated temporary fixtures and shell tool doubles. Existing PowerShell runners remain native.

**Constraints:** Keep production domain/application dependencies unchanged. Add no source comments. Preserve failure exit codes, Unicode paths, test isolation, PTY scenarios, and Windows architecture checks. PTY tooling is Unix-only. Syntax highlighting language support remains unchanged.

1. Add the development package and port the architecture regression scenarios to Hspec; verify they fail before implementing the pure checker and filesystem adapter.
2. Port Bash runner regressions to Bash; verify the new pipeline expectation fails against the old runner, then update Bash/PowerShell, Makefile and CI.
3. Port all PTY scenarios to a Unix Haskell executable with bounded waits and bracketed resource cleanup.
4. Remove the four old scripts, cached bytecode and Nix dependency; update current documentation and the previous runner plan.
5. Verify the complete workspace tests, real architecture check, Bash and available PowerShell regressions, actual PTY scenarios, source syntax/formatting and final interpreter-reference scan.

**Baseline:** `stack test` passes all four existing suites (97 examples).

**Progress:** All five steps complete. Changes remain in the supplied working tree without commits or branch changes.

## Verification

- `stack test --ghc-options=-Werror`: all 116 examples across five suites pass, including 19 development-tool examples.
- `stack run hfm-check-architecture`: the actual workspace passes.
- `bash scripts/run.sh test`: the complete real runner pipeline passes.
- `bash scripts/test-run-scripts.sh`: pipeline order, literal paths, source selection, failure exit codes, cleanup, missing tools, help and actual formatter checks pass.
- PowerShell 7.7 on Linux: native runner regressions pass; native Windows and macOS execution remain unverified.
- The complete Haskell PTY suite passes, including ten repeated shutdowns. An additional isolated startup/shutdown stress check passed 80 iterations.
- New Haskell sources pass HLint without hints; Bash syntax and `git diff --check` pass.
- No interpreter source or bytecode files remain, including ignored files. Active scripts, CI, Nix and development documentation contain no obsolete invocation or dependency.

## Review findings resolved

- Added executable source directories to format/lint discovery after Bash and PowerShell fixture tests reproduced the omission.
- Added character-literal and qualified-name regressions so concrete effects remain detectable after valid literals and through qualified identifiers.
- Reproduced the PTY shutdown race on the seventh stress iteration. EOF or a PTY hardware fault now waits briefly for confirmed child termination; unrelated or persistent errors still propagate. Descriptor ownership and cleanup are bracketed, and missing-process errors are handled narrowly during termination.
