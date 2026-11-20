set -eu
cli=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
root=$(mktemp -d)
trap 'chmod u+rwx "$root/projects/blocked" "$root/reference-projects/blocked" 2>/dev/null || :; rm -rf -- "$root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Tester GIT_COMMITTER_NAME=Tester
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

expect_exit() {
    expected=$1
    shift
    actual=0
    "$@" >"$root/output" 2>"$root/error" || actual=$?
    if [ "$actual" -ne "$expected" ]; then
        cat "$root/output" "$root/error"
        printf 'expected exit %s, got %s\n' "$expected" "$actual" >&2
        exit 1
    fi
}

mkdir "$root/projects" "$root/empty" "$root/-projects"
expect_exit 0 "$cli" --help
expect_exit 2 "$cli" ""
expect_exit 2 "$cli" --dry-run --dry-run "$root/empty"
expect_exit 2 "$cli" --verbose --verbose "$root/empty"
expect_exit 2 "$cli" "$root/empty" "$root/projects"
expect_exit 2 "$cli" --unknown
expect_exit 2 "$cli" --jobs 0 "$root/empty"
expect_exit 2 "$cli" --jobs many "$root/empty"
expect_exit 2 "$cli" --jobs 2 --jobs 2 "$root/empty"
expect_exit 2 "$cli" --jobs "$root/empty"
expect_exit 0 "$cli" --jobs 2 "$root/empty"
expect_exit 2 "$cli" "$root/nonexistent"
expect_exit 0 "$cli" "$root/empty"
grep -q 'No Git worktrees found' "$root/output"
(cd "$root" && expect_exit 0 "$cli" -- -projects)

git init -q -b main --bare "$root/remote"
git clone -q "$root/remote" "$root/publisher" 2>/dev/null
git -C "$root/publisher" commit --allow-empty -qm initial
git -C "$root/publisher" push -q origin main
for name in a-diverged 'z clean' dirty detached untracked; do
    git clone -q "$root/remote" "$root/projects/$name"
done
git -C "$root/projects/a-diverged" commit --allow-empty -qm diverged
touch "$root/projects/dirty/untracked"
git -C "$root/projects/detached" switch -q --detach
git -C "$root/projects/untracked" branch --unset-upstream
ln -s "$root/publisher" "$root/projects/link"
git -C "$root/publisher" commit --allow-empty -qm update
git -C "$root/publisher" push -q origin main
git -C "$root/projects/z clean" config pull.squash true
git -C "$root/projects/z clean" config branch.main.rebase true
old_head=$(git -C "$root/projects/z clean" rev-parse HEAD)
diverged_head=$(git -C "$root/projects/a-diverged" rev-parse HEAD)
new_head=$(git -C "$root/publisher" rev-parse HEAD)

expect_exit 0 env TERM=xterm "$cli" --dry-run "$root/projects"
test ! -s "$root/error"
if [ -n "${REFERENCE_GIT_PULLER:-}" ]; then
    env TERM=xterm "$REFERENCE_GIT_PULLER" --dry-run "$root/projects" >"$root/reference-output" 2>"$root/reference-error"
    diff -u "$root/reference-output" "$root/output"
    diff -u "$root/reference-error" "$root/error"
fi
expect_exit 0 env TERM=dumb "$cli" --dry-run "$root/projects"
test ! -s "$root/error"
cp "$root/output" "$root/concurrent-output"
expect_exit 0 env TERM=dumb "$cli" --jobs 1 --dry-run "$root/projects"
diff -u "$root/output" "$root/concurrent-output"
grep -q 'planned=2' "$root/output"
grep -q 'skipped=3' "$root/output"
grep -q 'detached-head' "$root/output"
grep -q 'no-upstream' "$root/output"
grep -q 'dirty' "$root/output"
test "$(git -C "$root/projects/z clean" rev-parse HEAD)" = "$old_head"
test "$(git -C "$root/projects/z clean" rev-parse origin/main)" = "$old_head"
test "$(git -C "$root/projects/a-diverged" rev-parse HEAD)" = "$diverged_head"
test "$(git -C "$root/projects/a-diverged" rev-parse origin/main)" = "$old_head"

if [ "$(uname -s)" = Linux ] && command -v script >/dev/null; then
    printf -v command '%q ' "$cli" --dry-run "$root/projects"
    TERM=xterm script -qec "$command" /dev/null >"$root/terminal"
    grep -Fq 'Scanning: 5 repositories found' "$root/terminal"
    if grep -Fq 'processed "' "$root/terminal"; then
        exit 1
    fi
    grep -Fq '[####################] 5/5 processed' "$root/terminal"
    grep -Fq 'Summary updated=0 planned=2 skipped=3 failed=0' "$root/terminal"
    if grep -Fq 'Inspecting ' "$root/terminal"; then
        exit 1
    fi
    TERM=dumb script -qec "$command" /dev/null >"$root/dumb-terminal"
    grep -Fq 'Summary updated=0 planned=2 skipped=3 failed=0' "$root/dumb-terminal"
    if LC_ALL=C grep -q "$(printf '\033')" "$root/dumb-terminal"; then
        exit 1
    fi
fi

expect_exit 0 env TERM=xterm "$cli" --verbose --dry-run "$root/projects"
grep -Fxq 'Scanning: 5 repositories found' "$root/error"
grep -Fxq '[####################] 5/5 processed' "$root/error"
grep -Fq 'Inspecting ' "$root/error"
grep -Fq 'planned ' "$root/error"
test "$(head -n 1 "$root/output")" = 'Summary updated=0 planned=2 skipped=3 failed=0'
if LC_ALL=C grep -q "$(printf '\033')" "$root/error"; then
    exit 1
fi
expect_exit 0 "$cli" --dry-run --verbose "$root/empty"
grep -Fxq '[####################] 0/0 processed' "$root/error"
(cd "$root" && expect_exit 0 "$cli" --verbose -- -projects)

if [ -n "${REFERENCE_GIT_PULLER:-}" ]; then
    cp -R "$root/projects" "$root/reference-projects"
    mkdir "$root/reference-projects/blocked"
    chmod 000 "$root/reference-projects/blocked"
fi
mkdir "$root/projects/blocked"
chmod 000 "$root/projects/blocked"
expect_exit 1 "$cli" --verbose "$root/projects"
grep -Fq 'Pulling ' "$root/error"
grep -q 'updated=1' "$root/output"
grep -q 'skipped=3' "$root/output"
if [ "$(id -u)" -ne 0 ]; then
    grep -q 'blocked' "$root/error"
    grep -q 'failed=2' "$root/output"
fi
grep -q 'fast-forward' "$root/error"
test "$(git -C "$root/projects/z clean" rev-parse HEAD)" = "$new_head"
test "$(git -C "$root/projects/a-diverged" rev-parse HEAD)" = "$diverged_head"
test "$(git -C "$root/projects/dirty" rev-parse HEAD)" = "$old_head"

if [ -n "${REFERENCE_GIT_PULLER:-}" ]; then
    cp "$root/output" "$root/candidate-output"
    expect_exit 1 "$REFERENCE_GIT_PULLER" --verbose "$root/reference-projects"
    diff -u "$root/output" "$root/candidate-output"
    for name in a-diverged 'z clean' dirty detached untracked; do
        test "$(git -C "$root/projects/$name" rev-parse HEAD)" = \
             "$(git -C "$root/reference-projects/$name" rev-parse HEAD)"
    done
fi

mkdir "$root/bin"
expect_exit 2 env PATH="$root/bin" "$cli" "$root/empty"

ln -s "$root/empty" "$root/start-link"
expect_exit 2 "$cli" "$root/start-link/"
git init -q -b main --bare "$root/empty/bare"
git init -q -b main "$root/empty/한글"
git -C "$root/empty/한글" commit --allow-empty -qm initial
git -C "$root/empty/한글" worktree add -qb linked "$root/empty/linked"
git init -q -b main "$root/empty/한글/nested"
git init -q -b main "$root/empty/rebasing"
git -C "$root/empty/rebasing" commit --allow-empty -qm initial
mkdir "$root/empty/rebasing/.git/rebase-apply"
git init -q -b main "$root/empty/merging"
git -C "$root/empty/merging" commit --allow-empty -qm initial
git -C "$root/empty/merging" rev-parse HEAD >"$root/empty/merging/.git/MERGE_HEAD"
git -C "$root/empty/한글" -c protocol.file.allow=always submodule add -q "$root/remote" module
git init -q -b main "$root/empty/"$'with\nnewline\a\033'
mkdir -p "$root/empty/broken/.git"
trace="$root/git-trace"
expect_exit 1 env GIT_TRACE="$trace" GIT_DIR="$root/remote" GIT_WORK_TREE="$root" "$cli" --dry-run "$root/empty"
grep -Fq 'Summary updated=0 planned=0 skipped=7 failed=1' "$root/output"
grep -Fq '한글/nested" unborn-branch' "$root/output"
grep -Fq '한글/module" submodule' "$root/output"
grep -Fq 'with\nnewline\a\x1B;" unborn-branch' "$root/output"
grep -Fq 'linked" no-upstream' "$root/output"
grep -Fq 'rebasing" rebase-in-progress' "$root/output"
grep -Fq 'merging" merge-in-progress' "$root/output"
if grep -Eq 'built-in: git (pull|fetch)( |$)' "$trace"; then
    exit 1
fi
if [ -n "${REFERENCE_GIT_PULLER:-}" ]; then
    cp "$root/output" "$root/candidate-output"
    expect_exit 1 "$REFERENCE_GIT_PULLER" --dry-run "$root/empty"
    diff -u "$root/output" "$root/candidate-output"
fi
