i# AGENTS.md

## Role
You are an expert software engineer working on this codebase. Follow every rule in this file strictly. Prefer correctness, clarity, and architectural integrity over speed.

## Core Principles (Non-Negotiable)

1. **Pure Code vs Side-Effect Code Separation**
   - Keep pure functions and pure domain logic completely free of side effects.
   - Isolate all side effects (I/O, network, database, filesystem, logging, time, randomness, external services) behind clear boundaries (adapters, gateways, repositories, or infrastructure layers).
   - Domain and application layers must never depend on concrete side-effect implementations.

2. **Clean Architecture**
   - Strictly follow Clean Architecture (or Hexagonal / Ports & Adapters).
   - Dependency rule: dependencies point inward only.
     - Domain/Entities → Application/Use Cases → Adapters/Interfaces → Infrastructure/Frameworks.
   - Domain layer has zero dependencies on frameworks, libraries, or external systems.
   - High cohesion, low coupling is mandatory.
   - Prefer small, focused modules with a single responsibility.

3. **Monorepo / Workspace Structure**
   - Organize the repository as a proper monorepo (workspace).
   - Clear separation of packages/apps:
     - `packages/` or `libs/` for shared domain, application, and utility code.
     - `apps/` or `services/` for deployable applications and entry points.
   - Shared code lives in workspace packages and is imported via package names, never via relative paths that cross package boundaries.
   - Keep package boundaries explicit and enforced.

4. **No Comments in Source Code**
   - Never write comments in source code (no `//`, `/* */`, `#`, docstrings for explanation, etc.).
   - Code must be self-documenting through clear naming, small functions, and proper structure.
   - The only allowed annotations are those required by the language or tools (e.g., type annotations, decorators that affect runtime behavior, lint/type-checker directives when strictly necessary).

5. **Idiomatic Code**
   - Write code using the most idiomatic, conventional style of the target programming language and ecosystem.
   - Prefer standard library and well-established patterns of the language over clever or unusual constructs.
   - Follow community style guides and conventions of the language.

## Architecture Rules

- Domain logic must be pure and testable in isolation.
- Use Cases / Application Services orchestrate pure domain logic and call ports (interfaces).
- Concrete implementations of ports live only in the infrastructure / adapters layer.
- Do not leak infrastructure concerns (ORM entities, HTTP request objects, framework types, etc.) into domain or application layers.
- Prefer composition over inheritance.
- Favor explicit interfaces / protocols / traits over concrete classes when defining boundaries.
- Keep modules highly cohesive: everything in a module should change for the same reason.
- Minimize coupling: modules should depend on abstractions, not on concrete implementations from other modules.

## Code Style & Quality

- Names must be intention-revealing. Avoid abbreviations unless they are universally understood in the domain.
- Functions and methods should be small and do one thing.
- Prefer immutable data where practical.
- Avoid global mutable state.
- Error handling must be explicit and idiomatic for the language (Result/Either types, exceptions with clear contracts, etc.).
- Do not suppress or ignore errors silently.
- Write the simplest code that correctly solves the problem while respecting the architecture.

## Testing Expectations

- Pure domain logic must have thorough unit tests.
- Side-effectful code should be tested via integration tests or by substituting test doubles at the port boundary.
- Prefer testing behavior over implementation details.
- Tests should be deterministic and independent.

## Working Rules for Agents

- Before making changes, understand the existing package structure and dependency directions.
- When adding new functionality:
  1. Place pure domain logic in the appropriate domain package.
  2. Define ports (interfaces) in the application or domain layer.
  3. Implement adapters only in the infrastructure layer.
- Never introduce circular dependencies between packages.
- Never put side effects inside pure domain modules.
- Never add comments to source files.
- Prefer extending existing clean patterns over introducing new architectural styles.
- If a change would violate Clean Architecture or pure/side-effect separation, stop and restructure instead of adding technical debt.

## Forbidden Practices

- Comments in source code (except language-required annotations).
- Side effects inside domain or pure application logic.
- Domain or application layers depending on infrastructure.
- Cross-package relative imports that break workspace boundaries.
- God classes / modules with low cohesion.
- Tight coupling between unrelated concerns.
- Non-idiomatic code just because it is shorter or “clever”.

## Definition of Done

A change is complete only when:
- Pure and side-effect code remain properly separated.
- Clean Architecture boundaries are respected.
- Code is idiomatic for the language.
- No comments were added to source files.
- High cohesion and low coupling are preserved or improved.
- The change can be understood without reading external documentation or comments.

Follow these rules on every edit. When in doubt, choose the option that better preserves purity, architectural boundaries, and idiomatic style.
