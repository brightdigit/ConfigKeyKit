#!/bin/bash
set -euo pipefail

# SessionStart hook: install a Swift toolchain and lint tooling for Claude
# Code on the web (Linux). Only runs in remote sessions; local sessions are
# untouched.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFTLY_ENV="$HOME/.local/share/swiftly/env.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

persist_path() {
  # Make swift and mise available to later Bash commands in the session.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    {
      echo "export SWIFTLY_HOME_DIR=\"$HOME/.local/share/swiftly\""
      echo "export SWIFTLY_BIN_DIR=\"$HOME/.local/share/swiftly/bin\""
      echo "export PATH=\"$HOME/.local/share/swiftly/bin:$HOME/.local/bin:\$PATH\""
    } >> "$CLAUDE_ENV_FILE"
  fi
}

install_swift() {
  # System dependencies for Swift on Ubuntu 24.04 (per swift.org Linux
  # instructions), plus curl for fetching swiftly.
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    binutils \
    curl \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-13-dev \
    libncurses-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-13-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev

  # Install swiftly non-interactively, then the toolchain pinned by the
  # repo's .swift-version (falling back to latest if no pin resolves).
  local workdir
  workdir="$(mktemp -d)"
  pushd "$workdir" > /dev/null
  curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
  tar zxf "swiftly-$(uname -m).tar.gz"
  ./swiftly init -y --skip-install
  popd > /dev/null
  rm -rf "$workdir"

  # shellcheck disable=SC1090
  . "$SWIFTLY_ENV"

  cd "$PROJECT_DIR"
  if ! swiftly install -y; then
    echo "Pinned toolchain install failed; falling back to latest." >&2
    swiftly install -y latest
    swiftly use -y latest
  fi
}

install_lint_tools() {
  # Lint tooling (swift-format, SwiftLint, periphery) pinned via mise.toml.
  # The spm-backend tools compile from source, so the first run is slow;
  # container caching makes later sessions instant.
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v mise > /dev/null 2>&1; then
    curl -fsSL https://mise.run | sh
  fi
  mise trust --yes "$PROJECT_DIR/mise.toml"
  mise --cd "$PROJECT_DIR" install --yes
}

# Pick up a swiftly install from a previous (cached) hook run.
if [ -f "$SWIFTLY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$SWIFTLY_ENV"
fi

if command -v swift > /dev/null 2>&1; then
  echo "Swift already installed: $(swift --version 2>&1 | head -1)"
else
  install_swift
fi

# Lint tooling is secondary to the toolchain: warn loudly on failure but
# leave the session usable for building and testing.
if ! install_lint_tools; then
  echo "WARNING: lint tooling install failed; make lint will not work." >&2
  echo "WARNING: swift build/test are unaffected. See errors above." >&2
fi

persist_path
swift --version
