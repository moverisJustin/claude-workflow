#!/usr/bin/env bash
set -uo pipefail

# Validates the optional plugin packaging (.claude-plugin/plugin.json +
# marketplace.json + hooks/hooks.json) and — critically — guards against the
# plugin hook wiring drifting apart from settings.base.json (the install.sh
# path). Pure python3/bash. Exits non-zero on any failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "=== test-plugin.sh ==="

# 1. Manifests are valid JSON
if python3 -c "import json; json.load(open('$REPO/.claude-plugin/plugin.json'))" 2>/dev/null; then ok "plugin.json is valid JSON"; else bad "plugin.json invalid"; fi
if python3 -c "import json; json.load(open('$REPO/.claude-plugin/marketplace.json'))" 2>/dev/null; then ok "marketplace.json is valid JSON"; else bad "marketplace.json invalid"; fi
if python3 -c "import json; json.load(open('$REPO/hooks/hooks.json'))" 2>/dev/null; then ok "hooks/hooks.json is valid JSON"; else bad "hooks.json invalid"; fi

# 2. plugin.json agents list points to real files and excludes community
python3 - "$REPO" <<'PY'
import json, os, sys
repo=sys.argv[1]
p=json.load(open(f"{repo}/.claude-plugin/plugin.json"))
agents=p.get("agents",[])
bad=0
for a in agents:
    path=os.path.join(repo, a.lstrip("./"))
    if not os.path.isfile(path):
        print(f"  FAIL: plugin agent missing on disk: {a}"); bad=1
    if "community" in a:
        print(f"  FAIL: plugin bundles a community agent: {a}"); bad=1
core=len([f for f in os.listdir(f"{repo}/agents") if f.endswith(".md")])
if len(agents)!=core:
    print(f"  FAIL: plugin lists {len(agents)} agents but repo has {core} core agents"); bad=1
sys.exit(bad)
PY
[ $? -eq 0 ] && ok "plugin agents = the core set, all present, no community" || fail=$((fail+1))

# 3. marketplace plugin name matches plugin.json name; source is repo root
python3 - "$REPO" <<'PY'
import json, sys
repo=sys.argv[1]
pj=json.load(open(f"{repo}/.claude-plugin/plugin.json"))
mk=json.load(open(f"{repo}/.claude-plugin/marketplace.json"))
names=[x["name"] for x in mk.get("plugins",[])]
if pj["name"] not in names:
    print(f"  FAIL: plugin.json name '{pj['name']}' not listed in marketplace.json {names}"); sys.exit(1)
srcs=[x.get("source") for x in mk["plugins"] if x["name"]==pj["name"]]
if srcs[0] not in ("./","."):
    print(f"  FAIL: marketplace source for the root plugin should be './' , got {srcs[0]}"); sys.exit(1)
sys.exit(0)
PY
[ $? -eq 0 ] && ok "marketplace lists the plugin with repo-root source" || fail=$((fail+1))

# 4. hooks.json references only real hook scripts, all plugin-rooted
python3 - "$REPO" <<'PY'
import json, os, re, sys
repo=sys.argv[1]
h=json.load(open(f"{repo}/hooks/hooks.json"))["hooks"]
bad=0
for ev,entries in h.items():
    for e in entries:
        for hk in e.get("hooks",[]):
            cmd=hk.get("command","")
            if "~/.claude/scripts/" in cmd:
                print(f"  FAIL: plugin hook uses ~/.claude path (should be CLAUDE_PLUGIN_ROOT): {cmd}"); bad=1
            m=re.search(r'scripts/(hook-[a-z-]+\.sh)', cmd)
            if m and not os.path.isfile(f"{repo}/scripts/{m.group(1)}"):
                print(f"  FAIL: plugin hook references missing script: {m.group(1)}"); bad=1
sys.exit(bad)
PY
[ $? -eq 0 ] && ok "plugin hooks reference real, plugin-rooted scripts" || fail=$((fail+1))

# 5. CONSISTENCY: plugin hooks.json wires the SAME hook-scripts as settings.base.json
python3 - "$REPO" <<'PY'
import json, re, sys
repo=sys.argv[1]
def scripts_of(hooks):
    s=set()
    for ev,entries in hooks.items():
        for e in entries:
            for hk in e.get("hooks",[]):
                m=re.search(r'scripts/(hook-[a-z-]+\.sh)', hk.get("command",""))
                if m: s.add((ev, e.get("matcher","*"), m.group(1)))
    return s
base=scripts_of(json.load(open(f"{repo}/settings.base.json"))["hooks"])
plug=scripts_of(json.load(open(f"{repo}/hooks/hooks.json"))["hooks"])
if base!=plug:
    print("  FAIL: plugin hooks.json and settings.base.json hook wiring have DRIFTED")
    print("   only in settings:", sorted(base-plug))
    print("   only in plugin:  ", sorted(plug-base))
    sys.exit(1)
sys.exit(0)
PY
[ $? -eq 0 ] && ok "plugin hooks.json in sync with settings.base.json (no drift)" || fail=$((fail+1))

# 6. Optional: claude plugin validate, if the CLI is present
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$REPO" >/dev/null 2>&1; then ok "claude plugin validate passes"; else echo "  note  claude plugin validate reported issues (see: claude plugin validate .)"; fi
else
  echo "  SKIP  claude CLI not available for 'plugin validate'"
fi

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All plugin packaging tests passed."
