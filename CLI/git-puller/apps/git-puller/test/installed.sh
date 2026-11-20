set -eu
cli=$1
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Tester GIT_COMMITTER_NAME=Tester
export GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_EMAIL=test@example.invalid

"$cli" --help
git init -q -b main --bare "$root/remote"
git clone -q "$root/remote" "$root/writer"
git -C "$root/writer" commit --allow-empty -qm initial
git -C "$root/writer" push -q origin main
git clone -q "$root/remote" "$root/reader"
old_head=$(git -C "$root/reader" rev-parse HEAD)
git -C "$root/writer" commit --allow-empty -qm update
git -C "$root/writer" push -q origin main
new_head=$(git -C "$root/writer" rev-parse HEAD)

"$cli" --dry-run "$root/reader" >"$root/preview"
grep -Fxq 'Summary updated=0 planned=1 skipped=0 failed=0' "$root/preview"
test "$(git -C "$root/reader" rev-parse HEAD)" = "$old_head"
"$cli" "$root/reader" >"$root/update"
grep -Fxq 'Summary updated=1 planned=0 skipped=0 failed=0' "$root/update"
test "$(git -C "$root/reader" rev-parse HEAD)" = "$new_head"
