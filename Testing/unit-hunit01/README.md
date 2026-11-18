# README

## Format, lint, build, test, and run

Install Stack, Fourmolu, and HLint. With GHC and Cabal installed:

```bash
cabal update
cabal install fourmolu hlint
```

Make the tools available on `PATH`. Cabal's installation directory can be checked
with `cabal path --installdir`. The Bash script also searches `$HOME/.cabal/bin`.

```bash
./scripts/run.sh
```

On Windows, from PowerShell:

```powershell
.\scripts\run.ps1
```

The scripts format and lint the Haskell sources, build and test with Stack, and
run `unit-hunit01-exe`. They stop if any step fails, work from any directory,
and pass additional arguments to the application. Formatting updates source files
in place. Stack downloads the configured compiler and dependencies when needed.

## Install hackages

```bash
stack install HUnit
```

## Basic Stack Commands

```bash
$ stack new {project-name}
# or
$ stack new {project-name} quanterall/basic

$ stack build --test --file-watch --watch-all
# or
# build more faster
$ stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"

$ stack test --file-watch --watch-all
# or
# test automatically
$ ghcid --command "stack ghci test/Spec.hs"

# https://docs.haskellstack.org/en/stable/build_command/
$ stack test --coverage --fast --file-watch --watch-all --haddock

$ stack run
```

## Add hackages to project's package config file

```bash
vim package.yaml
```

```yaml
...

dependencies:
- base
- HUnit
```

## Add test code

Please check test/*.hs files

## Run test

```bash
$ stack test --file-watch --watch-all
```
