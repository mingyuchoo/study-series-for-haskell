# ADT workflows progress

Plan: `2026-11-19-adt-workflows.md`

- Baseline: 44 tests passed.
- Task 1: domain ADTs, transitions, discovery and search implemented; missing-module RED followed by 17 passing tests.
- Task 2: workflow and injected ports implemented; missing-module RED followed by 11 passing tests.
- Task 3: workspace and adapters connected; initial 78-test suite passed after fixing YAML file errors being hidden by decodeFileEither. Strict ByteString read now distinguishes file absence from parse failure.
- Independent review: found Unicode full lowercase expansion regression, repeated all-results projection, and repeated full-preview conversion. Unicode regression reproduced RED and fixed GREEN. Adapter projection and bounded String conversion tests added before implementation. Domain selection now uses a strict zipper cursor; terminal caches the derived Brick list; previews truncate before Text conversion.
- Strict full suite: domain 18, application 11, terminal 52; total 81 tests passed. `stack build --pedantic --fast` passed. HLint production sources, shell syntax, dependency boundaries and comment checks passed.
- PTY validation identified the existing Vty Ctrl+j/Enter ambiguity. Preserve key decoding behavior; document the down-arrow alternative. All 12 PTY scenarios passed, including filesystem input, piped input, filtering, empty results, query clear, Emacs/Vim navigation, dismissal output and resize warning/recovery.

Implementation decisions: execute in the supplied workspace and leave changes uncommitted. Preserve output for both Confirmed and Dismissed exits. Report previously silent configuration and discovery failures to stderr. Skip directory symlinks to prevent cycles while preserving file symlinks.

Final verification: all 81 tests passed with --pedantic, strict build passed, HLint reported no production hints, source/architecture checks and shell syntax passed. Docker COPY inputs and package metadata were checked; Docker image execution and PowerShell execution were not performed. All review findings were addressed. Changes remain uncommitted.
