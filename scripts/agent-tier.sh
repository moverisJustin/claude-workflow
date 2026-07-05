#!/usr/bin/env bash
# Shared helper: assign a model tier (and, for advisory personas, a read-only
# tool set) to a community agent by slug. Applied at DEPLOY time by install.sh
# to the copy in ~/.claude/agents/, so the vendored files stay upstream-faithful
# (easy to diff against agency-agents) and there is nothing to clobber on a
# resync. bash 3.2 + awk only; sourced, not executed.
#
# Tiering rationale:
#   - dev personas (engineering/testing/design/specialized) → sonnet, full tools
#     (they may need to read, write, and run things)
#   - advisory personas (sales/marketing/product/support/etc.) → haiku, and a
#     read-only tool set, since an unaudited third-party persona has no business
#     writing files or running bash by default

# exit 0 if the agent is an advisory (non-dev) persona that should be read-only.
# DENYLIST, not allowlist: only the explicitly-advisory categories are
# restricted, so a dev/technical agent whose slug lacks a tidy prefix (e.g.
# blockchain-security-auditor, agents-orchestrator, data-consolidation-agent)
# defaults to the dev tier (sonnet + full tools) instead of being silently
# downgraded to haiku + read-only.
community_is_advisory() {
  case "$1" in
    sales-*|marketing-*|product-*|project-management-*|project-manager-*|support-*|paid-media-*|game-*|godot-*|level-*|narrative-*|technical-artist|accounts-*|corporate-*|supply-*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

community_model() {
  if community_is_advisory "$1"; then echo haiku; else echo sonnet; fi
}

# inject_agent_frontmatter <file> <slug>
# Adds a `model:` line (if absent) and, for advisory agents lacking a `tools:`
# line, a read-only tool set. No-op if the file has no leading `---` fence.
inject_agent_frontmatter() {
  local file="$1" slug="$2" model tmp
  [ -f "$file" ] || return 0
  [ "$(head -1 "$file" 2>/dev/null)" = "---" ] || return 0

  if ! grep -q '^model:' "$file"; then
    model="$(community_model "$slug")"
    tmp="$file.tier.$$"
    awk -v m="$model" 'NR==1{print; print "model: " m; next} {print}' "$file" > "$tmp" 2>/dev/null \
      && mv "$tmp" "$file" || rm -f "$tmp"
  fi

  if community_is_advisory "$slug" && ! grep -q '^tools:' "$file"; then
    tmp="$file.tier.$$"
    awk 'NR==1{print; print "tools: Read, Grep, Glob, WebFetch, WebSearch"; next} {print}' "$file" > "$tmp" 2>/dev/null \
      && mv "$tmp" "$file" || rm -f "$tmp"
  fi
}
