# README

## Format, lint, build, test, and run

Install Stack, Fourmolu, and HLint and make sure they are available on `PATH`.
With GHC and Cabal installed, the formatting and linting tools can be installed with:

```sh
cabal update
cabal install fourmolu hlint
```

Add Cabal's executable directory to `PATH` (`cabal path --installdir` shows its location).
The PowerShell script supports Windows PowerShell 5.1 and PowerShell 7.

On Linux or macOS:

```sh
./scripts/run.sh
```

On Windows, from PowerShell:

```powershell
.\scripts\run.ps1
```

Both scripts format the root Haskell files and all Haskell files in `src`, `app`,
and `test` using `fourmolu.yaml`, lint them with HLint, build and test with Stack,
and run `integ-hspec01-exe`. They stop immediately if a tool is missing or a step
fails. Stack downloads the configured compiler and dependencies when needed.
The scripts work from any directory, and additional arguments are passed to the
application. Formatting updates source files in place.

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
- hspec
- QuickCheck
```

## Add test code

Please check test/*.hs files

## Run test

```bash
$ stack test --file-watch --watch-all
```
