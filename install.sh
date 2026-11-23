#!/bin/sh
# dbtunnel-rt installer — https://github.com/dyddtechnologies/dbtunnel-rt
#
#   curl -fsSL https://raw.githubusercontent.com/dyddtechnologies/dbtunnel-rt/main/install.sh | sh
#
# Detects your OS and CPU, downloads the matching binary from the GitHub Release, verifies it against
# SHA256SUMS and installs it for the current user (no sudo).
#
# Env:
#   DBTUNNEL_VERSION   release tag to install (default: latest), e.g. v1.0.0
#   DBTUNNEL_BIN_DIR   install directory (default: ~/.local/bin)
set -eu

REPO="dyddtechnologies/dbtunnel-rt"
VERSION="${DBTUNNEL_VERSION:-latest}"
BIN_DIR="${DBTUNNEL_BIN_DIR:-${HOME}/.local/bin}"

if [ -t 1 ]; then
  B="$(printf '\033[1m')"; G="$(printf '\033[32m')"; Y="$(printf '\033[33m')"; R="$(printf '\033[31m')"; N="$(printf '\033[0m')"
else
  B=""; G=""; Y=""; R=""; N=""
fi
say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '  %s✘ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

say "${B}dbtunnel-rt installer${N}"

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) die "unsupported OS '$(uname -s)'. On Windows, use WSL2 (Ubuntu) and run this again." ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) die "unsupported CPU '$(uname -m)' (supported: x86_64, arm64)" ;;
esac
asset="dbtunnel-rt-${os}-${arch}"
ok "platform: ${os}/${arch}"

if [ "$VERSION" = "latest" ]; then
  base="https://github.com/${REPO}/releases/latest/download"
else
  base="https://github.com/${REPO}/releases/download/${VERSION}"
fi

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    die "curl or wget is required"
  fi
}

tmp="$(mktemp -d 2>/dev/null || mktemp -d -t dbtunnel)"
trap 'rm -rf "$tmp"' EXIT INT TERM

fetch "${base}/${asset}" "${tmp}/${asset}" || die "download failed: ${base}/${asset} (does release '${VERSION}' exist?)"
fetch "${base}/SHA256SUMS" "${tmp}/SHA256SUMS" || die "download failed: ${base}/SHA256SUMS"
ok "downloaded ${asset} (${VERSION})"

expected="$(awk -v f="$asset" '$2 == f || $2 == "*"f { print $1 }' "${tmp}/SHA256SUMS")"
[ -n "$expected" ] || die "${asset} is not listed in SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${tmp}/${asset}" | awk '{ print $1 }')"
else
  actual="$(shasum -a 256 "${tmp}/${asset}" | awk '{ print $1 }')"
fi
[ "$expected" = "$actual" ] || die "checksum mismatch for ${asset} (expected ${expected}, got ${actual})"
ok "checksum verified (sha256 ${actual%"${actual#????????????}"}…)"

mkdir -p "$BIN_DIR"
cp "${tmp}/${asset}" "${BIN_DIR}/dbtunnel-rt"
chmod 0755 "${BIN_DIR}/dbtunnel-rt"
[ "$os" = darwin ] && xattr -d com.apple.quarantine "${BIN_DIR}/dbtunnel-rt" 2>/dev/null || true
ok "installed ${BIN_DIR}/dbtunnel-rt ($("${BIN_DIR}/dbtunnel-rt" version))"

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) warn "${BIN_DIR} is not in your PATH. Add this to your ~/.zshrc or ~/.bashrc:"
     say "      export PATH=\"${BIN_DIR}:\$PATH\"" ;;
esac
command -v aws >/dev/null 2>&1 || warn "AWS CLI v2 not found: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
command -v session-manager-plugin >/dev/null 2>&1 || warn "Session Manager plugin not found: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"

say ""
say "${B}Next:${N}"
say "  1. Put your bases file at ~/.config/dbtunnel/bases.conf"
say "  2. dbtunnel-rt doctor <base>"
say "  3. dbtunnel-rt <base>"
