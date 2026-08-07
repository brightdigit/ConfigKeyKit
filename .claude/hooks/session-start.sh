#!/bin/bash
set -euo pipefail

# SessionStart hook: install a Swift toolchain for Claude Code on the web
# (Linux). Only runs in remote sessions; local sessions are untouched.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFTLY_ENV="$HOME/.local/share/swiftly/env.sh"

persist_path() {
  # Make swift available to later Bash commands in the session.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    {
      echo "export SWIFTLY_HOME_DIR=\"$HOME/.local/share/swiftly\""
      echo "export SWIFTLY_BIN_DIR=\"$HOME/.local/share/swiftly/bin\""
      echo "export PATH=\"$HOME/.local/share/swiftly/bin:\$PATH\""
    } >> "$CLAUDE_ENV_FILE"
  fi
}

# Pick up a swiftly install from a previous (cached) hook run.
if [ -f "$SWIFTLY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$SWIFTLY_ENV"
fi

if command -v swift > /dev/null 2>&1; then
  echo "Swift already installed: $(swift --version 2>&1 | head -1)"
  if [ -f "$SWIFTLY_ENV" ]; then
    persist_path
  fi
  exit 0
fi

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
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"
curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
tar zxf "swiftly-$(uname -m).tar.gz"
./swiftly init -y --skip-install

# shellcheck disable=SC1090
. "$SWIFTLY_ENV"

cd "${CLAUDE_PROJECT_DIR:-$PWD}"
if ! swiftly install -y; then
  echo "Pinned toolchain install failed; falling back to latest." >&2
  swiftly install -y latest
  swiftly use -y latest
fi

persist_path
swift --version
