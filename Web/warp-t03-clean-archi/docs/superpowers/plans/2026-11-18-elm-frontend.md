# Elm Frontend Implementation Plan

**Goal:** Replace the vanilla frontend with Elm 0.19.3 and apply DESIGN.md to the existing user CRUD interface.

**Architecture:** An npm workspace contains apps/frontend. Domain.User owns pure validation and filtering. Application.Management owns pure state transitions and describes effects. Infrastructure.Effects dispatches effects to separate HTTP and browser-focus adapters. Presentation modules render the interface; Main connects Browser.element to these boundaries.

**Tech Stack:** Elm 0.19.3, elm/html, elm/http, elm-explorations/test, Playwright, existing Haskell WAI/Warp.

**Spec:** DESIGN.md and AGENTS.md.

## Constraints and decisions

- Use the existing JSON API and preserve all CRUD operations.
- Cream canvas #faf9f5, coral #cc785c, dark #181715; serif regular display, humanist body, 1200px container, 8px controls and 12px cards.
- Keep implementation in the user's current checkout; preserve their untracked instructions and design.
- Introduce no shared package until code actually needs sharing. Elm modules remain inside one explicitly named workspace package.
- Keep search local, make writes exclusive, preserve failed input, confirm deletion, expose retry and accessible feedback.
- Use documented local font fallbacks without requiring licensed fonts or remote font requests.
- Retain the existing backend package layout; this frontend migration does not restructure backend domain code.

## Tasks

- [x] Write and run failing domain and state transition tests; implement pure rules and typed effects; run the Elm suite.
- [x] Implement the HTTP adapter, Elm entry point, responsive view, CSS design tokens, and generated bundle route; compile optimized Elm.
- [x] Integrate npm build and tests into Make, shell, PowerShell, Docker, and README; ignore generated output and dependencies.
- [x] Exercise CRUD, search, confirmation, errors, XSS-safe rendering, and mobile width in browser tests; verify the backend build and report existing suite limits.
- [x] Review the full diff, address substantive findings, and rerun affected checks.

## Review focus

- Whitespace names must not reach the API.
- Duplicate submissions and selection changes must not corrupt in-flight writes.
- Failed writes must preserve input and allow retry.
- Hostile names must render as text.
- Mobile content must fit without horizontal page overflow; keyboard users must reach every action.


## Verification results

- Pinned npm compiler reports Elm 0.19.3; optimized build succeeds.
- Elm unit tests: 22 passed, including invalid names, filtering, exclusive writes, retry, confirmation cancellation, creation shortcuts, and focus effects.
- Chromium browser tests: 33 passed across 1440px desktop, 768px tablet, and 390px mobile. Includes a real 15-second request timeout, recovery, CRUD payloads, mobile navigation, safe text rendering, keyboard submission, and overflow checks.
- Real Warp integration: passed with a temporary SQLite database and the compiled frontend; creates, edits, and deletes through Chromium, then closes the server and removes the database.
- Haskell application and test compilation passed. The existing full suite was run in an isolated temporary directory and exceeded a six-second limit because Given Lib / appRunner starts a persistent server. The remaining suite passed with `stack test --test-arguments=--skip=appRunner` (2 examples).
- Docker frontend stage built successfully from an empty Elm cache. The slim Node image needed ca-certificates for Elm package downloads; the Dockerfile now installs them.
- Elm formatting, Bash syntax, and git diff whitespace checks passed. PowerShell runtime and the full Haskell Docker image were not executed.
- npm reports seven development dependency advisories through elm-test glob dependencies; production dependency audit reports zero. No patched compatible release was available in the registry checked during this task.

## Review resolutions

An independent review found three substantive issues. Each was reproduced before its fix: search/refresh could hide a blocking deletion confirmation; GET had no timeout; and Add a person could retain an existing edit selection. State tests and browser regressions now cover these cases. A further state test covers search while a deletion fails. No review findings remain deferred.
