#!/usr/bin/env bash
# install-bspec-cli.sh — OPT-IN installer for the pinned BSpec CLI (v1.1.2).
#
# This is NOT run by install.sh. The bspec-doc skill authors documents with
# Claude and scripts/bspec-validate.sh enforces conformance offline, so the CLI
# is NOT required for the workflow. Install it only if you want the corpus
# tooling: `bspec init | pack | open | query` over a directory of BSpec docs.
# (The released CLI has no offline generate/validate — those need an external
# OpenRouter/OpenAI key — which is exactly why we don't depend on it.)
#
# Pinned + checksum-verified: the project ships no checksums file and self-labels
# an in-flux version, so we pin the exact bytes reviewed at build time.
#
# Usage: bash scripts/install-bspec-cli.sh
set -euo pipefail

TAG="v1.1.2"
DEST_DIR="${HOME}/.claude/bin"
DEST="${DEST_DIR}/bspec"

os=$(uname -s); arch=$(uname -m)
case "$os" in
  Darwin) os=darwin ;;
  Linux)  os=linux ;;
  *) echo "Unsupported OS '$os'. Install manually from https://github.com/a3tai/bspec/releases/tag/${TAG}"; exit 1 ;;
esac
case "$arch" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64)  arch=amd64 ;;
  *) echo "Unsupported arch '$arch'. Install manually from https://github.com/a3tai/bspec/releases/tag/${TAG}"; exit 1 ;;
esac
asset="bspec-${os}-${arch}"

# Pinned SHA-256 for each v1.1.2 release asset (computed + reviewed at build time).
case "$asset" in
  bspec-darwin-arm64) want="45b19e1b0223629a03c7ff4e31322175e7207258ae922f39f369f6c770a5216d" ;;
  bspec-darwin-amd64) want="9771e2be9480fa9a6c41fe3eb5dd341c842e9f5162241e8dc9e6ffcf3b5b90d2" ;;
  bspec-linux-amd64)  want="95b2e62e9d939621afd6b1223c72fda4c461da733374bc798ba899bd42ccbf5c" ;;
  bspec-linux-arm64)  want="331017c56a8c8405111b47ff206aceb316f730125322c8d296de3dc1e2b7f01b" ;;
  *) echo "No pinned checksum for $asset"; exit 1 ;;
esac

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# Idempotent: already present at the pinned bytes?
if [ -f "$DEST" ] && [ "$(sha256 "$DEST")" = "$want" ]; then
  echo "bspec ${TAG} already installed at $DEST"
  exit 0
fi

mkdir -p "$DEST_DIR"
url="https://github.com/a3tai/bspec/releases/download/${TAG}/${asset}"
tmp="$(mktemp)"
echo "Downloading ${asset} (${TAG})..."
if ! curl -fsSL "$url" -o "$tmp"; then
  echo "Download failed. Install manually: $url"; rm -f "$tmp"; exit 1
fi
got="$(sha256 "$tmp")"
if [ "$got" != "$want" ]; then
  echo "CHECKSUM MISMATCH for $asset — refusing to install."
  echo "  expected $want"
  echo "  got      $got"
  rm -f "$tmp"; exit 1
fi
chmod +x "$tmp"
mv "$tmp" "$DEST"
echo "Installed bspec ${TAG} -> $DEST"

case ":$PATH:" in
  *":$DEST_DIR:"*) : ;;
  *) echo "Note: ~/.claude/bin is not on your PATH. To run 'bspec' directly:"
     echo "  echo 'export PATH=\"\$HOME/.claude/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
esac
