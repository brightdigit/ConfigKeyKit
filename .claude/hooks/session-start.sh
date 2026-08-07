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

# Build a SwiftPM executable from a public GitHub repo at a pinned tag and
# drop the binary into TOOLS_BIN. Web sessions cannot use `mise install`
# for this: the session's GitHub gateway scopes api.github.com to repos
# attached to the session, and mise's version resolution 403s on the tool
# repos. Anonymous public git clones and release-asset downloads do work,
# so the hook installs the same pinned versions through those paths.
build_spm_tool() {
  local repo="$1" tag="$2" binary="$3" workdir
  workdir="$(mktemp -d)"
  git clone --depth 1 --branch "$tag" "https://github.com/$repo.git" "$workdir/src"
  swift build --package-path "$workdir/src" -c release --product "$binary"
  install -m 755 "$workdir/src/.build/release/$binary" "$TOOLS_BIN/$binary"
  rm -rf "$workdir"
}

install_lint_tools() {
  local swiftlint_version swift_format_version periphery_version workdir
  swiftlint_version="$(mise_pin 'aqua:realm/SwiftLint')"
  swift_format_version="$(mise_pin 'spm:swiftlang/swift-format')"
  periphery_version="$(mise_pin 'spm:peripheryapp/periphery')"
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

  if command -v swift-format > /dev/null 2>&1 \
    && swift-format --version | grep -q "$swift_format_version"; then
    echo "swift-format $swift_format_version already installed."
  else
    build_spm_tool "swiftlang/swift-format" "$swift_format_version" "swift-format"
    echo "swift-format $swift_format_version installed."
  fi

  if command -v periphery > /dev/null 2>&1 \
    && periphery version | grep -q "$periphery_version"; then
    echo "periphery $periphery_version already installed."
  else
    build_spm_tool "peripheryapp/periphery" "$periphery_version" "periphery"
    echo "periphery $periphery_version installed."
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
