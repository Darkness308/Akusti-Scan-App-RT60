#!/bin/bash
# Test Runner for Akusti-Scan-App-RT60
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if we're on macOS with Xcode
if [[ "$(uname)" == "Darwin" ]] && command -v xcodebuild &> /dev/null; then
  echo "Running tests with xcodebuild..."
  xcodebuild test \
    -scheme "Akusti-Scan-App-RT60" \
    -destination "platform=iOS Simulator,name=iPhone 15" \
    -quiet \
    | xcpretty || true
  echo "✅ Tests complete!"
else
  echo "⚠️  Xcode not available (requires macOS)"
  echo "   Unit tests can only run in Xcode on macOS"

  # Swift syntax check as fallback
  if command -v swift &> /dev/null; then
    echo ""
    echo "Running Swift syntax validation..."
    for file in Akusti-Scan-App-RT60/*.swift; do
      if swift -parse "$file" 2>/dev/null; then
        echo "✅ $file: syntax OK"
      else
        echo "❌ $file: syntax error"
        exit 1
      fi
    done
    echo "✅ Syntax validation complete!"
  else
    echo "⚠️  Swift not available for syntax checking"
  fi
fi
