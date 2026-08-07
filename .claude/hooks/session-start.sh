#!/bin/bash
set -euo pipefail

# SessionStart hook: install a Swift toolchain and lint tooling for Claude
# Code on the web (Linux). Only runs in remote sessions; local sessions are
# untouched. Runs async so the session starts immediately: progress lands in
# ~/.claude-session-setup.log and ~/.claude-session-setup.done marks the end.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo '{"async": true, "asyncTimeout": 2400000}'

SETUP_LOG="$HOME/.claude-session-setup.log"
SETUP_DONE="$HOME/.claude-session-setup.done"
rm -f "$SETUP_DONE"
exec >> "$SETUP_LOG" 2>&1

SWIFTLY_ENV="$HOME/.local/share/swiftly/env.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
TOOLS_BIN="$HOME/.local/bin"

# Make swift and the lint tools reachable for the session up front; entries
# pointing at not-yet-populated directories are harmless.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export SWIFTLY_HOME_DIR=\"$HOME/.local/share/swiftly\""
    echo "export SWIFTLY_BIN_DIR=\"$HOME/.local/share/swiftly/bin\""
    echo "export PATH=\"$HOME/.local/share/swiftly/bin:$TOOLS_BIN:\$PATH\""
  } >> "$CLAUDE_ENV_FILE"
fi

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

# Read a tool's pinned version out of mise.toml so the pins have one source
# of truth shared with CI and local dev.
mise_pin() {
  sed -n "s|.*$1\" *= *\"\([^\"]*\)\".*|\1|p" "$PROJECT_DIR/mise.toml"
}

# Install SwiftLint from its prebuilt Linux release binary. Web sessions
# cannot use `mise install` for this: the session's GitHub gateway scopes
# api.github.com to repos attached to the session, and mise's version
# resolution 403s on the tool repos. Anonymous release-asset downloads do
# work, so the hook installs the same pinned version through that path.
# The other lint tools are deliberately NOT installed here: swift-format
# ships inside the Swift toolchain (swiftly proxies it), and periphery is
# skipped in web sessions entirely (Scripts/lint.sh omits the scan when
# CLAUDE_CODE_REMOTE is set), keeping session cold-start fast.
install_lint_tools() {
  local swiftlint_version workdir
  swiftlint_version="$(mise_pin 'aqua:realm/SwiftLint')"
  mkdir -p "$TOOLS_BIN"
  export PATH="$TOOLS_BIN:$PATH"

  if command -v swiftlint > /dev/null 2>&1 \
    && [ "$(swiftlint --version)" = "$swiftlint_version" ]; then
    echo "SwiftLint $swiftlint_version already installed."
  else
    workdir="$(mktemp -d)"
    curl -fsSL -o "$workdir/swiftlint.zip" \
      "https://github.com/realm/SwiftLint/releases/download/$swiftlint_version/swiftlint_linux_amd64.zip"
    unzip -q -o "$workdir/swiftlint.zip" -d "$workdir"
    install -m 755 "$workdir/swiftlint" "$TOOLS_BIN/swiftlint"
    rm -rf "$workdir"
    echo "SwiftLint $swiftlint_version installed."
  fi
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

# SwiftLint on Linux dlopens libsourcekitdInProc.so and finds it through
# LINUX_SOURCEKIT_LIB_PATH; resolve it now that the toolchain exists.
sourcekit_lib="$(find "$HOME/.local/share/swiftly/toolchains" \
  -name libsourcekitdInProc.so -exec dirname {} \; 2> /dev/null | head -1)"
if [ -n "$sourcekit_lib" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export LINUX_SOURCEKIT_LIB_PATH=\"$sourcekit_lib\"" >> "$CLAUDE_ENV_FILE"
fi

swift --version
touch "$SETUP_DONE"
