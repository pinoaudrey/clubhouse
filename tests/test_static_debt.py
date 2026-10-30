"""Tests for reading the Static findings out of ~/pitch/bin/static.mjs.

The block carries a count and a link that opens a session, so both have to fail
closed: every way of not getting an answer produces no block, and the link is
dropped unless it is the one claude:// shape the card may open.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import static_debt
from static_debt import collect_static

LINK = "claude://code/new?q=raya%20please%20fix%0A&folder=%2Ftmp%2Fpitch"

REPORT = {
    "score": 102,
    "band": "CRITICAL",
    "generated_at": "2026-10-29T19:34:00.000Z",
    "findings": [],
    "fix": {"count": 34, "folder": "/tmp/pitch", "prompt": "raya please fix\n", "link": LINK},
}


def _fake_pitch(tmp_path: Path, stdout: str, exit_code: int = 0, sleep: int = 0) -> tuple[Path, str]:
    """A throwaway workspace, and a fake node that ignores the script it is handed."""
    root = tmp_path / "pitch"
    (root / "bin").mkdir(parents=True)
    (root / "bin" / "static.mjs").write_text("// stand-in\n")
    node = tmp_path / "node"
    node.write_text(f"#!/bin/sh\nsleep {sleep}\ncat <<'EOF'\n{stdout}\nEOF\nexit {exit_code}\n")
    node.chmod(0o755)
    return root, str(node)


def test_the_count_and_link_come_from_the_engine(tmp_path: Path):
    root, node = _fake_pitch(tmp_path, json.dumps(REPORT))
    assert collect_static(root, node) == {
        "generated_at": "2026-10-29T19:34:00.000Z",
        "score": 102,
        "band": "CRITICAL",
        "count": 34,
        "fix_link": LINK,
    }


def test_a_clear_workspace_reads_zero_with_no_link(tmp_path: Path):
    root, node = _fake_pitch(tmp_path, json.dumps({**REPORT, "score": 0, "band": "CLEAR", "fix": None}))
    block = collect_static(root, node)
    assert block["count"] == 0
    assert block["fix_link"] is None


def test_an_engine_without_the_fix_field_is_unknown_not_clear(tmp_path: Path):
    """Merge order does not decide install order. An older static.mjs scores
    findings but carries no count, and reading that as zero would hide them."""
    report = {k: v for k, v in REPORT.items() if k != "fix"}
    root, node = _fake_pitch(tmp_path, json.dumps(report))
    assert collect_static(root, node) is None


def test_a_link_with_another_scheme_is_dropped(tmp_path: Path):
    report = {**REPORT, "fix": {**REPORT["fix"], "link": "https://example.com/?q=x"}}
    root, node = _fake_pitch(tmp_path, json.dumps(report))
    block = collect_static(root, node)
    assert block["count"] == 34
    assert block["fix_link"] is None


def test_a_failed_run_omits_the_block(tmp_path: Path):
    root, node = _fake_pitch(tmp_path, json.dumps(REPORT), exit_code=1)
    assert collect_static(root, node) is None


def test_output_that_is_not_json_omits_the_block(tmp_path: Path):
    root, node = _fake_pitch(tmp_path, "Static 102 [CRITICAL]")
    assert collect_static(root, node) is None


def test_a_missing_workspace_omits_the_block(tmp_path: Path):
    _, node = _fake_pitch(tmp_path, json.dumps(REPORT))
    assert collect_static(tmp_path / "nowhere", node) is None


def test_no_node_omits_the_block(tmp_path: Path, monkeypatch):
    root, _ = _fake_pitch(tmp_path, json.dumps(REPORT))
    monkeypatch.setattr(static_debt, "find_node", lambda: None)
    assert collect_static(root) is None


def test_node_is_found_off_the_daemon_path(monkeypatch, tmp_path: Path):
    """The app starts the daemon with a PATH that has no node on it."""
    fallback = tmp_path / "node"
    fallback.write_text("#!/bin/sh\n")
    fallback.chmod(0o755)
    monkeypatch.setenv("PATH", "/usr/bin:/bin")
    monkeypatch.setattr(static_debt, "_NODE_FALLBACKS", (str(tmp_path / "absent"), str(fallback)))
    if static_debt.shutil.which("node"):
        return  # this machine has node in /usr/bin; the fallback never runs
    assert static_debt.find_node() == str(fallback)


def test_a_hung_engine_gives_up_rather_than_holding_the_poll(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(static_debt, "STATIC_TIMEOUT_SECONDS", 0.2)
    root, node = _fake_pitch(tmp_path, json.dumps(REPORT), sleep=30)
    assert collect_static(root, node) is None
