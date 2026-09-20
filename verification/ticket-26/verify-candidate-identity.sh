#!/usr/bin/env bash
#
# Confirms a checkout still holds the exact candidate bound to issue #26.
#
# The archive recipe below must stay byte-identical to the one recorded in the
# candidate bundle. A different prefix or a different gzip level produces a
# different digest for the same tree, which would look like a changed candidate.
set -euo pipefail

readonly expected_commit=625d5a22c57d7ab0f792330a3bb7eaa0880f7304
readonly expected_tree=8f3e33a03b1609d2957c63367a4a9c471b6e4ef6
readonly expected_archive_sha256=1eb0a56ca3cff03012884ef7cb7e8dc0c659b8b8db4ccf39d52a0fb75b3a9e5f
readonly archive_prefix=hibermachy-helper-0.1.0/

repo=${1:-$(git rev-parse --show-toplevel)}

fail() {
  printf 'HBR-T26-IDENTITY FAIL: %s\n' "$*" >&2
  exit 1
}

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "not a Git worktree: $repo"

actual_type=$(git -C "$repo" cat-file -t "$expected_commit" 2>/dev/null) \
  || fail "candidate commit object is unavailable"
[[ "$actual_type" == commit ]] || fail "candidate object type is $actual_type, expected commit"

actual_commit=$(git -C "$repo" rev-parse --verify "${expected_commit}^{commit}") \
  || fail "cannot resolve the candidate commit"
[[ "$actual_commit" == "$expected_commit" ]] || fail "commit mismatch: $actual_commit"

actual_tree=$(git -C "$repo" rev-parse "${expected_commit}^{tree}") \
  || fail "cannot resolve the candidate tree"
[[ "$actual_tree" == "$expected_tree" ]] || fail "tree mismatch: $actual_tree"

actual_archive_sha256=$(git -C "$repo" archive --format=tar --prefix="$archive_prefix" \
  "$expected_commit" | gzip -n -9 | sha256sum | awk '{print $1}') \
  || fail "cannot reproduce the candidate archive digest"
[[ "$actual_archive_sha256" == "$expected_archive_sha256" ]] \
  || fail "archive SHA-256 mismatch: $actual_archive_sha256"

printf '%s\n' \
  'HBR-T26-IDENTITY PASS' \
  "commit=$actual_commit" \
  "tree=$actual_tree" \
  "archive_recipe=git archive --format=tar --prefix=$archive_prefix <commit> | gzip -n -9" \
  "archive_sha256=$actual_archive_sha256"
