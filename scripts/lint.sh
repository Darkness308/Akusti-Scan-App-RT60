#!/bin/bash
# SwiftLint Runner for Akusti-Scan-App-RT60
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! command -v swiftlint &> /dev/null; then
  echo "❌ SwiftLint not installed. Install with:"
  echo "   brew install swiftlint (macOS)"
  echo "   Or run session-start hook in Claude Code Remote"
  exit 1
fi

echo "Running SwiftLint..."
swiftlint lint --config .swiftlint.yml

echo "✅ Linting complete!"
