"""Static findings, read from the Pitch workspace's bin/static.mjs.

`static.mjs --json` scores the dead references and other debt in ~/pitch, and
builds the prompt and the claude:// link that hand every finding to the Raya
seat in a new Claude Code session. This module runs it and passes on the count
and the link, so the card and the Pitch dashboard send the same prompt.

Like setup_health, it fails closed: no workspace, no node, a crash, a hang, or
output that is not the contract produces no block at all, and the card says
"unknown" rather than "clear".
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

# The engine walks the workspace in under a second (2026-10-29).
STATIC_TIMEOUT_SECONDS = 30.0

# The only link the card will open. Anything else in the field is dropped.
LINK_PREFIX = "claude://code/new?"

# The app starts the daemon with PATH=/usr/bin:/bin:/usr/sbin:/sbin, which has
# no node, so the usual install locations are tried after PATH.
_NODE_FALLBACKS = ("/opt/homebrew/bin/node", "/usr/local/bin/node")


def static_script_path(pitch_dir: Path | None = None) -> Path:
    """Where the engine lives. PITCH_DIR overrides it, so tests can point it at
    a throwaway workspace."""
    root = pitch_dir or Path(os.environ.get("PITCH_DIR") or Path.home() / "pitch")
    return Path(root) / "bin" / "static.mjs"


def find_node() -> str | None:
    found = shutil.which("node")
    if found:
        return found
    return next((p for p in _NODE_FALLBACKS if os.access(p, os.X_OK)), None)


def collect_static(pitch_dir: Path | None = None, node: str | None = None) -> dict | None:
    """The static block, or None when the question could not be asked."""
    script = static_script_path(pitch_dir)
    node = node or find_node()
    if not script.is_file() or not node:
        return None
    try:
        out = subprocess.run(
            [node, str(script), "--json"],
            capture_output=True,
            text=True,
            timeout=STATIC_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    try:
        report = json.loads(out.stdout)
    except ValueError:
        return None
    return _block(report)


def _block(report) -> dict | None:
    if not isinstance(report, dict):
        return None
    score, band = report.get("score"), report.get("band")
    if not isinstance(score, int) or not isinstance(band, str):
        return None
    fix = report.get("fix")
    if fix is None:
        # The engine predates the fix handoff, or nothing needs attention. Only
        # a zero score proves the second.
        return _shape(report, count=0, link=None) if score == 0 else None
    if not isinstance(fix, dict) or not isinstance(fix.get("count"), int):
        return None
    link = fix.get("link")
    if not isinstance(link, str) or not link.startswith(LINK_PREFIX):
        link = None
    return _shape(report, count=fix["count"], link=link)


def _shape(report: dict, count: int, link: str | None) -> dict:
    return {
        "generated_at": report.get("generated_at"),
        "score": report["score"],
        "band": report["band"],
        "count": count,
        "fix_link": link,
    }
