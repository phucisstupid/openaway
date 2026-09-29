#!/usr/bin/env bash
# Run the deterministic core tests using only Swift and Foundation. This fallback
# executes the same test bodies as `swift test` on Macs whose Command Line Tools
# do not include XCTest. Use `swift test` with full Xcode installed for XCTest.
# To choose the standalone tools explicitly, prefix this command with
# DEVELOPER_DIR=/Library/Developer/CommandLineTools.
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openaway-core-tests.XXXXXX")"
trap 'rm -rf "$TEST_WORK_DIR"' EXIT

python3 - "$PROJECT_ROOT" "$TEST_WORK_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
destination = Path(sys.argv[2]) / "CoreVerification.swift"
parts = [r'''
import Foundation

// These assertions deliberately abort on failure so the shell receives a
// nonzero status. The XCTest source remains the single source of test cases.
class XCTestCase {}
private var assertionCount = 0
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    precondition(actual == expected, "Expected \(expected), received \(actual) at \(file):\(line)")
}
func XCTAssertEqual(_ actual: Double, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    precondition(abs(actual - expected) <= accuracy, "Expected \(expected), received \(actual) at \(file):\(line)")
}
func XCTAssertTrue(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    precondition(actual, "Expected true at \(file):\(line)")
}
func XCTAssertFalse(_ actual: Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    precondition(!actual, "Expected false at \(file):\(line)")
}
func XCTAssertNil<T>(_ actual: T?, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    precondition(actual == nil, "Expected nil at \(file):\(line)")
}
func XCTFail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    preconditionFailure("\(message) at \(file):\(line)")
}
''']

for source in sorted((root / "Sources/OpenAwayCore").glob("*.swift")):
    parts.append(source.read_text())

calls = []
for source in sorted((root / "Tests/OpenAwayCoreTests").glob("*.swift")):
    body = source.read_text()
    parts.append(body.replace("import XCTest", "").replace("@testable import OpenAwayCore", ""))
    test_class = re.search(r"final class (\w+)\s*:\s*XCTestCase", body)
    if test_class is None:
        raise SystemExit(f"Cannot discover a test class in {source}")
    for method, throwing in re.findall(r"func (test\w+)\(\)\s*(throws)?", body):
        calls.append(f'{"try " if throwing else ""}{test_class.group(1)}().{method}()')

if not calls:
    raise SystemExit("No core tests found.")
parts.extend(calls)
parts.append(f'print("PASS: {len(calls)} core test cases, \\(assertionCount) assertions (Foundation fallback runner).")')
destination.write_text("\n".join(parts))
PY

mkdir -p "$PROJECT_ROOT/.build/ModuleCache"
CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache" \
    swift -module-cache-path "$PROJECT_ROOT/.build/ModuleCache" "$TEST_WORK_DIR/CoreVerification.swift"
