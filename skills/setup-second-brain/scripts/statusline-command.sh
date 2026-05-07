#!/usr/bin/env bash
input=$(cat)

# Terminal width — try tput first, then $COLUMNS, then default
width=$(tput cols 2>/dev/null)
[[ -z "$width" || "$width" == "0" ]] && width="${COLUMNS:-120}"

# ---- ccusage: short-TTL cached fetch (3s) with in-flight de-dup ----
CCUSAGE_CACHE="/tmp/ccusage-statusline.json"
CCUSAGE_STAMP="/tmp/ccusage-statusline.ts"
CCUSAGE_TTL=3
_now=$(date +%s)
_stale=1
if [[ -f "$CCUSAGE_STAMP" ]]; then
    _ts=$(cat "$CCUSAGE_STAMP" 2>/dev/null || echo 0)
    (( _now - _ts < CCUSAGE_TTL )) && _stale=0
fi
if [[ $_stale -eq 1 ]]; then
    # Bump the stamp BEFORE forking so concurrent renders don't all spawn
    # their own ccusage processes during the ~1–2s fetch window.
    echo "$_now" > "$CCUSAGE_STAMP"
    (
        _result=$(npx --yes ccusage@latest blocks --active --json 2>/dev/null)
        if [[ -n "$_result" ]]; then
            printf '%s' "$_result" > "$CCUSAGE_CACHE"
            date +%s > "$CCUSAGE_STAMP"
        fi
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
fi
ccusage_json=""
[[ -f "$CCUSAGE_CACHE" ]] && ccusage_json=$(cat "$CCUSAGE_CACHE" 2>/dev/null)

# ---- rate-limits cache (persists last-known five_hour / seven_day) ----
RATE_CACHE="/tmp/claude-rate-limits.json"
rate_cache_json=""
[[ -f "$RATE_CACHE" ]] && rate_cache_json=$(cat "$RATE_CACHE" 2>/dev/null)

python3 - "$input" "$width" "$HOME" "$ccusage_json" "$rate_cache_json" "$RATE_CACHE" <<'PY'
import json, sys, os, re
from datetime import datetime, timezone
from unicodedata import east_asian_width

raw, term_width, home = sys.argv[1], int(sys.argv[2]), sys.argv[3]
ccusage_raw = sys.argv[4] if len(sys.argv) > 4 else ""
rate_cache_raw = sys.argv[5] if len(sys.argv) > 5 else ""
rate_cache_path = sys.argv[6] if len(sys.argv) > 6 else ""
try:
    d = json.loads(raw)
except Exception:
    d = {}

m  = d.get("model") or {}
cw = d.get("context_window") or {}
rl = d.get("rate_limits") or {}

model         = m.get("display_name") or ""
# Drop the " context" suffix so "Opus 4.7 (1M context)" → "Opus 4.7 (1M)"
model         = re.sub(r"\s*context", "", model)
five_hour_obj = rl.get("five_hour") or {}
seven_day_obj = rl.get("seven_day") or {}

def to_pct(v):
    try:
        return round(float(v))
    except (TypeError, ValueError):
        return 0

ctx_pct      = to_pct(cw.get("used_percentage"))
five_hour    = to_pct(five_hour_obj.get("used_percentage"))
seven_day    = to_pct(seven_day_obj.get("used_percentage"))
five_resets  = five_hour_obj.get("resets_at", "")
seven_resets = seven_day_obj.get("resets_at", "")

# ---- rate-limits cache: fall back to last-known values on fresh sessions ----
def parse_iso(s):
    if s is None or s == "":
        return None
    if isinstance(s, (int, float)):
        try:
            return datetime.fromtimestamp(s, tz=timezone.utc)
        except (OSError, OverflowError, ValueError):
            return None
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s)
    except Exception:
        return None

def cache_alive(iso):
    dt = parse_iso(iso)
    return bool(dt and dt > datetime.now(timezone.utc))

five_from_cache = False
seven_from_cache = False
try:
    cache = json.loads(rate_cache_raw) if rate_cache_raw else {}
except Exception:
    cache = {}

# A live input has a real resets_at timestamp. If the field is empty the
# session hasn't talked to the API yet; substitute cached values that are
# still inside their reset window.
if not five_resets and isinstance(cache.get("five_hour"), dict):
    cf = cache["five_hour"]
    if cache_alive(cf.get("resets_at")):
        five_hour = to_pct(cf.get("used_percentage"))
        five_resets = cf.get("resets_at", "")
        five_from_cache = True

if not seven_resets and isinstance(cache.get("seven_day"), dict):
    cs = cache["seven_day"]
    if cache_alive(cs.get("resets_at")):
        seven_day = to_pct(cs.get("used_percentage"))
        seven_resets = cs.get("resets_at", "")
        seven_from_cache = True

# Persist live values so future fresh sessions can read them back.
if rate_cache_path:
    new_cache = dict(cache) if isinstance(cache, dict) else {}
    if five_hour_obj.get("resets_at"):
        new_cache["five_hour"] = {
            "used_percentage": five_hour_obj.get("used_percentage", 0),
            "resets_at": five_hour_obj.get("resets_at"),
        }
    if seven_day_obj.get("resets_at"):
        new_cache["seven_day"] = {
            "used_percentage": seven_day_obj.get("used_percentage", 0),
            "resets_at": seven_day_obj.get("resets_at"),
        }
    if new_cache != cache:
        try:
            with open(rate_cache_path, "w") as f:
                json.dump(new_cache, f)
        except Exception:
            pass

def bar(pct, color):
    filled = (pct + 5) // 10
    filled = max(0, min(10, filled))
    return f"\033[{color}m{'█'*filled}{'░'*(10-filled)}\033[0m"

def fmt_reset_at(iso):
    dt = parse_iso(iso)
    if not dt:
        return ""
    local = dt.astimezone()
    hour12 = local.hour % 12 or 12
    suffix = "AM" if local.hour < 12 else "PM"
    if local.minute == 0:
        return f"{hour12}{suffix}"
    return f"{hour12}:{local.minute:02d}{suffix}"

def fmt_reset_in(iso):
    dt = parse_iso(iso)
    if not dt:
        return ""
    now = datetime.now(timezone.utc)
    total = int((dt - now).total_seconds())
    if total <= 0:
        return "now"
    days = total // 86400
    hours = (total % 86400) // 3600
    mins = (total % 3600) // 60
    if days > 0:
        return f"{days}d{hours}h" if hours else f"{days}d"
    if hours > 0:
        return f"{hours}h{mins}m" if mins else f"{hours}h"
    return f"{mins}m"

# Width tiers — drop trailing detail as the pane shrinks. Session tokens
# are always shown (the user wants this stat regardless of pane width).
include_resets = term_width >= 100
include_bars   = term_width >= 70

# ---- Context segment (color shifts as it fills) ----
if ctx_pct >= 90:
    ctx_color = "0;31"   # red
elif ctx_pct >= 75:
    ctx_color = "0;33"   # yellow
else:
    ctx_color = "0;36"   # cyan
parts = [f"🧠 \033[{ctx_color}m{ctx_pct}%\033[0m"]

# ---- 5h bar ----
five_color = "0;31" if five_hour >= 90 else ("0;33" if five_hour >= 75 else "0;32")
if include_bars:
    five_label = f"⏱️ {bar(five_hour, five_color)} \033[{five_color}m{five_hour}%\033[0m"
else:
    five_label = f"⏱️ \033[{five_color}m{five_hour}%\033[0m"
if include_resets:
    five_reset_str = fmt_reset_at(five_resets)
    if five_reset_str:
        five_label += f" \033[2m→{five_reset_str}\033[0m"
parts.append(five_label)

# ---- 7d bar ----
seven_color = "0;31" if seven_day >= 90 else ("0;33" if seven_day >= 75 else "0;34")
if include_bars:
    seven_label = f"📅 {bar(seven_day, seven_color)} \033[{seven_color}m{seven_day}%\033[0m"
else:
    seven_label = f"📅 \033[{seven_color}m{seven_day}%\033[0m"
if include_resets:
    seven_reset_str = fmt_reset_in(seven_resets)
    if seven_reset_str:
        seven_label += f" \033[2m→{seven_reset_str}\033[0m"
parts.append(seven_label)

def fmt_tokens(n):
    n = int(n or 0)
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n//1000}k"
    return f"{n}"

# ---- ccusage active block ----
if ccusage_raw:
    try:
        cu = json.loads(ccusage_raw)
        # ccusage returns either an object with a "blocks" array or a direct array
        if isinstance(cu, list):
            blocks = cu
        else:
            blocks = cu.get("blocks") or []
        # Find the active block (isActive or active == True)
        active = next(
            (b for b in blocks if b.get("isActive") or b.get("active")),
            None
        )
        if active is None and blocks:
            active = blocks[0]
        if active:
            burn = active.get("burnRate") or {}
            cost_per_hr = burn.get("costPerHour")
            if cost_per_hr is not None:
                parts.append(f"🔥 \033[1;31m${float(cost_per_hr):.2f}/hr\033[0m")
            tok_per_min = burn.get("tokensPerMinute")
            if tok_per_min is not None:
                parts.append(f"🪙 \033[1;33m{fmt_tokens(float(tok_per_min) * 60)}/hr\033[0m")
    except Exception:
        pass


print("  ".join(parts))
PY
