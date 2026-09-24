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

import fcntl
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

LOCK_FILE = CACHE_FILE.with_suffix(".lock")

# The usage endpoint has a tight (undocumented) rate limit, and waybar
# runs one copy of this script per monitor every 30s. So: serve the
# cache for FRESH_S (the reset countdown is recomputed locally, so the
# bar stays live), serialize fetches with a lock so only one bar
# instance calls the API, and back off exponentially after a 429 —
# retrying on every poll keeps the limiter window saturated forever.
FRESH_S       = 600     # one API call per 10 min at most
STALE_OK_S    = 3600    # show cached values up to 1h old during outages
BACKOFF_MIN_S = 120
BACKOFF_MAX_S = 1800


def emit(text, tooltip, css_class):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))


def read_cache():
    try:
        return json.loads(CACHE_FILE.read_text())
    except (FileNotFoundError, OSError, ValueError):
        return {}


def write_cache(state):
    try:
        CACHE_FILE.write_text(json.dumps(state))
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
    # Hold the lock for the whole run so concurrent bar instances wait
    # for the first one's result instead of all hitting the API.
    with open(LOCK_FILE, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        run()


def run():
    state = read_cache()
    cache_at = state.get("at", 0)
    cached = state.get("data")
    now_s = time.time()

    # Serve fresh cache without hitting the API at all.
    if cached and (now_s - cache_at) < FRESH_S:
        render(cached, now_s - cache_at)
        return

    # Still backing off from an earlier failure: don't call the API.
    if now_s < state.get("retry_at", 0):
        err_msg = state.get("last_error", "backing off")
    else:
        err_msg = None
        try:
            data = fetch_usage()
            write_cache({"at": now_s, "data": data})
            render(data, 0)
            return
        except FileNotFoundError:
            emit("󰚩 ?", "No Claude credentials at ~/.claude/.credentials.json", "error")
            return
        except HTTPError as e:
            if e.code == 401:
                err_msg = "auth expired — run `claude` to refresh"
            elif e.code == 429:
                err_msg = "rate-limited"
            else:
                err_msg = f"HTTP {e.code}"
            try:
                retry_after = int(e.headers.get("Retry-After") or 0)
            except ValueError:
                retry_after = 0
        except (URLError, TimeoutError, OSError) as e:
            err_msg, retry_after = f"network: {e}", 0
        except (KeyError, ValueError) as e:
            err_msg, retry_after = f"bad payload: {e}", 0

        # Exponential backoff, honoring Retry-After when it's meaningful.
        backoff = min(max(state.get("backoff", 0) * 2, BACKOFF_MIN_S), BACKOFF_MAX_S)
        state.update(backoff=backoff, last_error=err_msg,
                     retry_at=now_s + max(backoff, retry_after))
        write_cache(state)

    # API call failed. If we have a not-too-stale cached value, render
    # that with a warning marker rather than flashing red on the bar.
    if cached and (now_s - cache_at) < STALE_OK_S:
        render(cached, now_s - cache_at, was_error=err_msg)
        return

    emit("󰚩 auth?" if "auth" in err_msg else "󰚩 ?",
         f"Claude usage API error: {err_msg}", "error")


if __name__ == "__main__":
    main()
