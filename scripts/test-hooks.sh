#!/bin/bash
# Exercise the real formatter in an isolated repository; never touch this checkout's index.
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PROJECT_ROOT/.githooks/pre-commit"
xcrun --find swift-format > /dev/null
TEST_WORK=$(mktemp -d "${TMPDIR:-/tmp}/openaway-hook-tests.XXXXXX")
trap 'rm -rf "$TEST_WORK"' EXIT
git init -q "$TEST_WORK/repo"
cd "$TEST_WORK/repo"
git config user.name 'Hook Test'
git config user.email 'hook-test@example.invalid'
printf '{"indentation":{"spaces":4},"lineLength":120}\n' > .swift-format
printf 'struct Example {\n    let value = 1\n}\n' > Main.swift
git add -- .swift-format Main.swift
git -c core.hooksPath=/dev/null commit -qm baseline
checks=0

check() {
    local name="$1" expected="$2" status
    git diff --binary > "$TEST_WORK/work-before"
    cp .git/index "$TEST_WORK/index-before"
    if "$HOOK" > "$TEST_WORK/output" 2>&1; then status=0; else status=$?; fi
    if [[ "$status" -ne "$expected" ]] || ! cmp -s .git/index "$TEST_WORK/index-before"; then
        echo "FAIL: $name (exit $status; expected $expected; index must stay unchanged)" >&2
        cat "$TEST_WORK/output" >&2
        exit 1
    fi
    git diff --binary > "$TEST_WORK/work-after"
    if ! cmp -s "$TEST_WORK/work-before" "$TEST_WORK/work-after"; then
        echo "FAIL: $name changed the working tree" >&2
        exit 1
    fi
    checks=$((checks + 1))
    git reset --hard -q HEAD
}

printf 'struct Example {\n    let value = 2\n}\n' > Main.swift
git add -- Main.swift
check 'formatted staged Swift' 0

printf 'struct Example{let value=2}\n' > Main.swift
git add -- Main.swift
check 'unformatted staged Swift' 1

printf 'struct Example {\n    let value = 2\n}\n' > Main.swift
git add -- Main.swift
printf 'struct Example{let value=2}\n' > Main.swift
check 'formatted index with unformatted working tree' 0

printf 'struct Example{let value=2}\n' > Main.swift
git add -- Main.swift
printf 'struct Example {\n    let value = 2\n}\n' > Main.swift
check 'unformatted index with formatted working tree' 1

printf '{"indentation":{"spaces":4},"lineLength":121}\n' > .swift-format
git add -- .swift-format
printf 'invalid working-tree configuration\n' > .swift-format
check 'staged configuration with different working-tree configuration' 0

printf '{"indentation":{"spaces":2},"lineLength":120}\n' > .swift-format
git add -- .swift-format
check 'configuration-only change lints unchanged indexed Swift' 1

printf 'invalid staged configuration\n' > .swift-format
git add -- .swift-format
check 'invalid staged configuration' 1

printf 'text change\n' > Notes.txt
git add -- Notes.txt
check 'no Swift changes' 0

git rm -q -- Main.swift
check 'deleted Swift file' 0

git mv -- Main.swift Renamed.swift
check 'renamed Swift file' 0

unusual=$'--space and\nnewline.swift'
printf 'struct Example{let value=2}\n' > "$unusual"
git add -- "$unusual"
check 'new Swift filename containing spaces and a newline' 1

printf 'struct Example {\n    let value = 2\n}\n' > "$unusual"
git add -- "$unusual"
check 'formatted Swift filename with a leading dash, spaces and a newline' 0

git rm -q -- Main.swift
printf '{"indentation":{"spaces":4},"lineLength":121}\n' > .swift-format
git add -- .swift-format
check 'valid configuration with no indexed Swift files' 0

git rm -q -- Main.swift
printf 'invalid staged configuration\n' > .swift-format
git add -- .swift-format
check 'invalid configuration with no indexed Swift files' 1

mkdir "$TEST_WORK/bin"
printf '#!/bin/sh\nexit 1\n' > "$TEST_WORK/bin/xcrun"
chmod +x "$TEST_WORK/bin/xcrun"
printf 'struct Example {\n    let value = 2\n}\n' > Main.swift
git add -- Main.swift
PATH="$TEST_WORK/bin:$PATH" check 'missing formatter' 1
if [[ $(cat "$TEST_WORK/output") != *'Swift lint requires swift-format'* ]]; then
    echo 'FAIL: missing formatter did not explain the requirement' >&2
    exit 1
fi
echo "PASS: $checks staged-content hook checks; index and working tree unchanged."
