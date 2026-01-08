#!/bin/bash
set -euo pipefail

# Only run in remote Claude Code environment
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Setting up Swift development environment..."

install_swift() {
  # Check if Swift is already installed
  if command -v swift &> /dev/null; then
    echo "✅ Swift already installed: $(swift --version 2>&1 | head -1)"
    return 0
  fi

  echo "Installing Swift toolchain..."

  # Install dependencies for Swift (ignore errors as some may already exist)
  apt-get update -qq 2>/dev/null || true
  apt-get install -y -qq \
    binutils \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-11-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-11-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
    curl \
    2>/dev/null || true

  # Download and install Swift 5.10
  SWIFT_VERSION="5.10.1"
  SWIFT_PLATFORM="ubuntu22.04"
  SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2204/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-${SWIFT_PLATFORM}.tar.gz"

  if curl -fsSL "$SWIFT_URL" -o /tmp/swift.tar.gz 2>/dev/null; then
    tar -xzf /tmp/swift.tar.gz -C /opt
    rm /tmp/swift.tar.gz

    # Add Swift to PATH
    if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      echo "export PATH=/opt/swift-${SWIFT_VERSION}-RELEASE-${SWIFT_PLATFORM}/usr/bin:\$PATH" >> "$CLAUDE_ENV_FILE"
    fi
    export PATH="/opt/swift-${SWIFT_VERSION}-RELEASE-${SWIFT_PLATFORM}/usr/bin:$PATH"

    echo "✅ Swift installed: $(swift --version 2>&1 | head -1)"
    return 0
  else
    echo "⚠️  Swift download failed - continuing without Swift"
    return 1
  fi
}

install_swiftlint() {
  # Check if SwiftLint is already installed
  if command -v swiftlint &> /dev/null; then
    echo "✅ SwiftLint already installed: $(swiftlint version 2>&1)"
    return 0
  fi

  echo "Installing SwiftLint..."

  # Install SwiftLint via prebuilt binary
  SWIFTLINT_VERSION="0.55.1"
  SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/swiftlint_linux.zip"

  if curl -fsSL "$SWIFTLINT_URL" -o /tmp/swiftlint.zip 2>/dev/null; then
    unzip -q /tmp/swiftlint.zip -d /tmp/swiftlint
    mv /tmp/swiftlint/swiftlint /usr/local/bin/swiftlint
    chmod +x /usr/local/bin/swiftlint
    rm -rf /tmp/swiftlint /tmp/swiftlint.zip

    echo "✅ SwiftLint installed: $(swiftlint version 2>&1)"
    return 0
  else
    echo "⚠️  SwiftLint download failed - continuing without SwiftLint"
    return 1
  fi
}

# Run installations (continue even if one fails)
SWIFT_OK=0
SWIFTLINT_OK=0

install_swift && SWIFT_OK=1 || true
install_swiftlint && SWIFTLINT_OK=1 || true

# Summary
echo ""
echo "=== Setup Summary ==="
if [ "$SWIFT_OK" -eq 1 ]; then
  echo "✅ Swift: Ready"
else
  echo "⚠️  Swift: Not available (manual syntax checking only)"
fi

if [ "$SWIFTLINT_OK" -eq 1 ]; then
  echo "✅ SwiftLint: Ready"
else
  echo "⚠️  SwiftLint: Not available"
fi

echo "===================="
echo "Swift development environment setup complete!"
