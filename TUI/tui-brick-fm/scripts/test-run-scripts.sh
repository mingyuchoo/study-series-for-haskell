#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPORARY="$(mktemp -d "${TMPDIR:-/tmp}/hfm scripts 한글.XXXXXX")"
trap 'rm -rf -- "$TEMPORARY"' EXIT
TEMPORARY="$(cd -- "$TEMPORARY" && pwd -P)"
export HFM_TEST_ROOT="$TEMPORARY/project [workspace]"
export HFM_TEST_LOG="$TEMPORARY/calls"
export HFM_TEST_FAIL=''
export HFM_TEST_ARCH=x86_64
CALLER="$TEMPORARY/caller"
BIN="$TEMPORARY/bin"
SCRATCH="$TEMPORARY/temporary files"
SOURCES=('apps/hfm/app/Main.hs' 'packages/hfm-domain/src/Some file 한글.hs' 'packages/hfm-domain/test/Spec.hs' 'packages/hfm-dev-tools/app/Main.hs' 'packages/hfm-dev-tools/pty/Terminal.hs')
mkdir -p "$HFM_TEST_ROOT/scripts" "$CALLER/left 한글 [files]" "$CALLER/right files" "$BIN" "$SCRATCH"
cp "$ROOT/scripts/run.sh" "$HFM_TEST_ROOT/scripts/run.sh"
for source in "${SOURCES[@]}" 'packages/hfm-domain/.stack-work/Generated.hs' 'apps/hfm/dist/Generated.hs' 'packages/hfm-domain/dist-newstyle/Generated.hs'; do
  mkdir -p "$HFM_TEST_ROOT/$(dirname -- "$source")"
  printf 'module Main where\n' > "$HFM_TEST_ROOT/$source"
done
cat > "$BIN/tool" <<'TOOL'
#!/bin/sh
name="${0##*/}"
[ "$PWD" = "$HFM_TEST_ROOT" ] || exit 99
printf '%s\t' "$name" "$@" >> "$HFM_TEST_LOG"
printf '\n' >> "$HFM_TEST_LOG"
case "$HFM_TEST_FAIL" in
  "$name"|"$name:${1-}"|"$name:${1-}:${2-}") exit 7 ;;
esac
TOOL
chmod +x "$BIN/tool"
for tool in stack stylish-haskell hlint; do ln -s tool "$BIN/$tool"; done
cat > "$BIN/uname" <<'UNAME'
#!/bin/sh
[ "$1" = -m ] || exit 1
printf '%s\n' "$HFM_TEST_ARCH"
UNAME
chmod +x "$BIN/uname"

fail() {
  printf '%s\n' "$*" >&2
  cat "$TEMPORARY/output" "$HFM_TEST_LOG" >&2
  exit 1
}

invoke() {
  : > "$HFM_TEST_LOG"
  STATUS=0
  (cd "$CALLER" && PATH="$BIN:/usr/bin:/bin" TMPDIR="$SCRATCH" bash "$HFM_TEST_ROOT/scripts/run.sh" "$@") > "$TEMPORARY/output" 2>&1 || STATUS=$?
}

expect_status() {
  [ "$STATUS" -eq "$1" ] || fail "Expected status $1, received $STATUS"
}

expect_count() {
  local count
  count="$(wc -l < "$HFM_TEST_LOG")"
  [ "$count" -eq "$1" ] || fail "Expected $1 tool calls, received $count"
}

record() {
  printf '%s\t' "$@"
  printf '\n'
}

for command in '' all; do
  if [ -n "$command" ]; then invoke "$command"; else invoke; fi
  expect_status 0
  {
    record stylish-haskell --config .stylish-haskell.yaml -i "${SOURCES[@]}"
    record hlint "${SOURCES[@]}"
    record stack build
    record stack run hfm-check-architecture
    record stack test
    record stack run hfm --
  } > "$TEMPORARY/expected"
  cmp -s "$TEMPORARY/expected" "$HFM_TEST_LOG" || fail 'Pipeline order or arguments changed'
done

for command in format lint; do
  invoke "$command"
  expect_status 0
  expect_count 1
  if [ "$command" = format ]; then
    record stylish-haskell --config .stylish-haskell.yaml -i "${SOURCES[@]}"
  else
    record hlint "${SOURCES[@]}"
  fi > "$TEMPORARY/expected"
  cmp -s "$TEMPORARY/expected" "$HFM_TEST_LOG" || fail 'Formatter or linter received unexpected sources'
done

count=0
for stage in stylish-haskell hlint stack:build stack:run:hfm-check-architecture stack:test stack:run:hfm; do
  count=$((count + 1))
  export HFM_TEST_FAIL="$stage"
  invoke all
  expect_status 7
  expect_count "$count"
done
export HFM_TEST_FAIL=''

for command in run all; do
  invoke "$command" 'left 한글 [files]' 'right files'
  expect_status 0
  record stack run hfm -- "$CALLER/left 한글 [files]" "$CALLER/right files" > "$TEMPORARY/expected"
  tail -n 1 "$HFM_TEST_LOG" > "$TEMPORARY/last"
  cmp -s "$TEMPORARY/expected" "$TEMPORARY/last" || fail 'Starting directories were not resolved from the caller'
done

for command in build format lint; do
  invoke "$command" .
  [ "$STATUS" -ne 0 ] || fail 'Unexpected directory argument was accepted'
  expect_count 0
done
for arguments in unknown missing file too-many; do
  case "$arguments" in
    unknown) invoke unknown ;;
    missing) invoke run missing ;;
    file) invoke run "$HFM_TEST_ROOT/scripts/run.sh" ;;
    too-many) invoke run . . . ;;
  esac
  [ "$STATUS" -ne 0 ] || fail 'Invalid arguments were accepted'
  expect_count 0
done

rm "$BIN/hlint"
invoke all
[ "$STATUS" -ne 0 ] || fail 'Missing linter was accepted'
expect_count 0
[[ "$(cat "$TEMPORARY/output")" == *hlint* ]] || fail 'Missing tool was not named'

export HFM_TEST_ARCH=arm64
invoke lint
expect_status 0
expect_count 0
for command in '' all; do
  if [ -n "$command" ]; then invoke "$command"; else invoke; fi
  expect_status 0
  {
    record stylish-haskell --config .stylish-haskell.yaml -i "${SOURCES[@]}"
    record stack build
    record stack run hfm-check-architecture
    record stack test
    record stack run hfm --
  } > "$TEMPORARY/expected"
  cmp -s "$TEMPORARY/expected" "$HFM_TEST_LOG" || fail 'Non-x86 pipeline must skip only HLint'
done
ln -s tool "$BIN/hlint"
invoke lint
expect_status 0
expect_count 0
invoke all
expect_status 0
cmp -s "$TEMPORARY/expected" "$HFM_TEST_LOG" || fail 'Non-x86 pipeline ran the installed HLint'
export HFM_TEST_ARCH=x86_64

printf '#!/bin/sh\nexit 9\n' > "$BIN/find"
chmod +x "$BIN/find"
invoke format
expect_status 9
expect_count 0
[ -z "$(ls -A "$SCRATCH")" ] || fail 'Source discovery leaked temporary files'
rm "$BIN/find"

for command in build test clean run; do
  invoke "$command"
  expect_status 0
  case "$command" in
    test) { record stack run hfm-check-architecture; record stack test; } ;;
    run) record stack run hfm -- ;;
    *) record stack "$command" ;;
  esac > "$TEMPORARY/expected"
  cmp -s "$TEMPORARY/expected" "$HFM_TEST_LOG" || fail 'Individual Stack command changed'
done

for tool in stack stylish-haskell hlint; do rm "$BIN/$tool"; done
invoke help
expect_status 0
expect_count 0
[[ "$(cat "$TEMPORARY/output")" == *format*lint* ]] || fail 'Help is incomplete'

if command -v stylish-haskell >/dev/null 2>&1; then
  printf 'main :: IO ()\nmain = pure ()\n' > "$TEMPORARY/Main.hs"
  for pass in 1 2; do
    stylish-haskell --config "$ROOT/.stylish-haskell.yaml" -i "$TEMPORARY/Main.hs"
  done
  if command -v ghc >/dev/null 2>&1; then
    cat > "$TEMPORARY/Platform.hs" <<'HASKELL'
{-# LANGUAGE CPP #-}
module Platform (platformValue) where
import Data.Bool (bool)
#if defined(mingw32_HOST_OS)
import Data.Maybe (isJust)
#else
import Data.Either (isRight)
#endif
platformValue :: Bool
#if defined(mingw32_HOST_OS)
platformValue = bool False True (isJust (Just ()))
#else
platformValue = bool False True (isRight (Right () :: Either () ()))
#endif
HASKELL
    for pass in 1 2; do
      stylish-haskell --config "$ROOT/.stylish-haskell.yaml" -i "$TEMPORARY/Platform.hs"
      for platform in -Umingw32_HOST_OS -Dmingw32_HOST_OS; do
        result="$(ghc -ignore-dot-ghci -v0 "$platform" "$TEMPORARY/Platform.hs" -e Platform.platformValue)" || fail 'Formatting broke platform-specific imports'
        [ "$result" = True ] || fail 'Formatting changed platform-specific behavior'
      done
    done
  else
    printf 'SKIP: formatted platform import checks (GHC unavailable)\n'
  fi
else
  printf 'SKIP: actual formatter configuration check (stylish-haskell unavailable)\n'
fi
printf 'Bash runner checks passed\n'
