#!/usr/bin/env python3
"""Waybar custom module: Claude Code usage from the OAuth /usage endpoint.

Hits https://api.anthropic.com/api/oauth/usage with the OAuth access
token from ~/.claude/.credentials.json (the same credential the CLI's
`/usage` slash command uses), so the percentages match the CLI exactly.

No env-var configuration needed — works on any plan, on any machine
where Claude Code has been logged in. If the token has expired and the
CLI hasn't refreshed it yet, the widget shows "auth?" until the next
`claude` invocation refreshes the credential file.
"""

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

CREDENTIALS = Path.home() / ".claude" / ".credentials.json"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CACHE_FILE = Path("/tmp") / f"claude-usage-{Path.home().name}.json"
TIMEOUT_S = 8

# Cache successful responses so waybar's 30s polling — and any other
# concurrent caller — doesn't slam the endpoint. If the cache is fresh
# we serve it without an API call. If the API fails (rate limit, brief
# network blip), we serve the cached value up to STALE_OK_S old and
# label it as a stale read rather than an error.
FRESH_S    = 25     # under waybar's 30s interval, so each poll triggers ≤1 call
STALE_OK_S = 600    # tolerate cached values up to 10 minutes during outages


def emit(text, tooltip, css_class):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))


def read_cache():
    try:
        raw = json.loads(CACHE_FILE.read_text())
        return raw.get("at", 0), raw.get("data") or {}
    except (FileNotFoundError, OSError, ValueError):
        return 0, None


def write_cache(data):
    try:
        CACHE_FILE.write_text(json.dumps({"at": time.time(), "data": data}))
    except OSError:
        pass


def fmt_reset(ts_str, now):
    if not ts_str:
        return "—"
    try:
        ts = datetime.fromisoformat(ts_str)
    except ValueError:
        return "—"
    mins = max(int((ts - now).total_seconds() // 60), 0)
    h, m = divmod(mins, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m"


def fetch_usage():
    cred = json.loads(CREDENTIALS.read_text())["claudeAiOauth"]
    token = cred["accessToken"]
    req = Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "claude-usage-waybar/1.0",
        },
    )
    with urlopen(req, timeout=TIMEOUT_S) as r:
        return json.loads(r.read())


def classify(pct):
    if pct < 50:
        return "low"
    if pct < 80:
        return "medium"
    return "high"


def render(data, age_s, was_error=None):
    """Build the waybar JSON from a usage payload (live or cached)."""
    now = datetime.now(timezone.utc)
    five  = data.get("five_hour")  or {}
    seven = data.get("seven_day")  or {}
    pct_5h = float(five.get("utilization")  or 0.0)
    pct_7d = float(seven.get("utilization") or 0.0)
    reset_5h = fmt_reset(five.get("resets_at"),  now)
    reset_7d = fmt_reset(seven.get("resets_at"), now)

    text = f"󰚩 {pct_5h:.0f}% · {reset_5h}"
    if was_error:
        text += " ⚠"

    lines = ["Claude Code Usage"]
    if was_error:
        lines.append(f"  (cached — {was_error})")
    lines += [
        f"  5h:  {pct_5h:>5.1f}%    resets in {reset_5h}",
        f"  7d:  {pct_7d:>5.1f}%    resets in {reset_7d}",
    ]
    sonnet = (data.get("seven_day_sonnet") or {}).get("utilization")
    opus   = (data.get("seven_day_opus")   or {}).get("utilization")
    if sonnet is not None:
        lines.append(f"  7d sonnet: {float(sonnet):>5.1f}%")
    if opus is not None:
        lines.append(f"  7d opus:   {float(opus):>5.1f}%")

    extra = data.get("extra_usage") or {}
    if extra.get("is_enabled") and (extra.get("monthly_limit") or extra.get("used_credits")):
        used  = float(extra.get("used_credits")  or 0.0)
        limit = float(extra.get("monthly_limit") or 0.0)
        cur   = extra.get("currency", "USD")
        lines.append(f"  extra:    {used:.2f} / {limit:.2f} {cur}")

    if age_s is not None:
        lines.append(f"  fetched {int(age_s)}s ago")

    emit(text, "\n".join(lines), classify(pct_5h))


def main():
    cache_at, cached = read_cache()
    now_s = time.time()

    # Serve fresh cache without hitting the API at all.
    if cached and (now_s - cache_at) < FRESH_S:
        render(cached, now_s - cache_at)
        return

    try:
        data = fetch_usage()
        write_cache(data)
        render(data, 0)
        return
    except FileNotFoundError:
        emit("󰚩 ?", "No Claude credentials at ~/.claude/.credentials.json", "error")
        return
    except HTTPError as e:
        if e.code == 401:
            err_msg = "auth expired — run `claude` to refresh"
        elif e.code == 429:
            err_msg = "rate-limited (too many calls)"
        else:
            err_msg = f"HTTP {e.code}"
    except (URLError, TimeoutError, OSError) as e:
        err_msg = f"network: {e}"
    except (KeyError, ValueError) as e:
        err_msg = f"bad payload: {e}"

    # API call failed. If we have a not-too-stale cached value, render
    # that with a warning marker rather than flashing red on the bar.
    if cached and (now_s - cache_at) < STALE_OK_S:
        render(cached, now_s - cache_at, was_error=err_msg)
        return

    emit("󰚩 auth?" if "auth" in err_msg else "󰚩 ?",
         f"Claude usage API error: {err_msg}", "error")


if __name__ == "__main__":
    main()
