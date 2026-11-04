#!/usr/bin/env python3
"""Tests extract_sessions.py against the sample sessions in testdata/, run the
way the retro skill runs it: as a command, with each agent's home folder
pointed at a temporary one.

Usage: python3 test_extract_sessions.py
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "extract_sessions.py"
TESTDATA = HERE / "testdata"
DAY = "2026-11-02"


class ExtractSessionsTest(unittest.TestCase):
	def setUp(self):
		self.tmp = tempfile.TemporaryDirectory()
		root = Path(os.path.realpath(self.tmp.name))
		self.project = root / "project"
		self.project.mkdir()
		self.claude_home = root / "claude"
		self.copilot_home = root / "copilot"
		self.codex_home = root / "codex"

		# Claude Code: one folder per project, named after its path.
		folder = self.claude_home / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(self.project))
		self.install(TESTDATA / "claude.jsonl", folder / "claude-1.jsonl", self.project)
		# Copilot CLI: one folder per session, tied to a project by session.start.
		self.install(TESTDATA / "copilot-events.jsonl", self.copilot_home / "session-state" / "copilot-1" / "events.jsonl", self.project)
		# A Copilot session from another project, which must be left out.
		self.install(TESTDATA / "copilot-events.jsonl", self.copilot_home / "session-state" / "other" / "events.jsonl", root / "elsewhere")
		# Codex: every project's sessions filed by date, tied to one by session_meta.
		day = self.codex_home / "sessions" / "2026" / "11" / "02"
		self.install(TESTDATA / "codex-rollout.jsonl", day / "rollout-2026-11-02T16-00-00-codex-1.jsonl", self.project)
		self.install(TESTDATA / "codex-rollout.jsonl", day / "rollout-2026-11-02T16-00-00-other.jsonl", root / "elsewhere")

	def tearDown(self):
		self.tmp.cleanup()

	@staticmethod
	def install(src: Path, dest: Path, project: Path):
		dest.parent.mkdir(parents=True, exist_ok=True)
		dest.write_text(src.read_text(encoding="utf-8").replace("__PROJECT__", str(project)), encoding="utf-8")
		# The script skips files not touched near the window; keep them in it.
		os.utime(dest, None)

	def run_script(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
		env = dict(os.environ, CLAUDE_CONFIG_DIR=str(self.claude_home), COPILOT_HOME=str(self.copilot_home), CODEX_HOME=str(self.codex_home))
		return subprocess.run(
			[sys.executable, "-I", str(SCRIPT), "--scope", "day", "--date", DAY, "--cwd", str(cwd or self.project), *args],
			capture_output=True, text=True, env=env, check=False,
		)

	def sessions(self, *args: str) -> list[dict]:
		result = self.run_script(*args)
		self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
		return json.loads(result.stdout)

	def test_claude_session(self):
		[s] = self.sessions("--agent", "claude")
		p = str(self.project)
		self.assertEqual(s["agent"], "claude")
		self.assertEqual(s["session_id"], "claude-1")
		self.assertEqual(s["title"], "Add a cart total helper")
		self.assertEqual(s["branch"], "feature/totals")
		self.assertEqual(s["duration_minutes"], 12)
		self.assertEqual(s["user_prompts"][0], "Add a total() helper to cart.js")
		self.assertEqual(s["corrections"], ["No, not like that: use reduce instead of a loop"])
		self.assertEqual(s["skills_used"], ["commit"])
		self.assertEqual(s["files_read"], [f"{p}/cart.js"])
		self.assertEqual(s["files_edited"], [f"{p}/cart.js"])
		self.assertEqual(s["commits"], ["git add cart.js && git commit -m 'feat: add total()'"])
		self.assertEqual(s["tool_usage"], {"Read": 1, "Skill": 1, "Edit": 1, "Bash": 1})

	def test_copilot_session(self):
		[s] = self.sessions("--agent", "copilot")
		p = str(self.project)
		self.assertEqual(s["agent"], "copilot")
		self.assertEqual(s["session_id"], "copilot-1")
		self.assertEqual(s["title"], "Fix cart rounding")
		self.assertEqual(s["branch"], "fix/rounding")
		self.assertEqual(s["duration_minutes"], 9)
		self.assertEqual(s["user_prompts"][0], "Totals in cart.js are a cent off")
		self.assertEqual(s["corrections"], ["Don't round there, round when formatting instead"])
		self.assertEqual(s["skills_used"], ["commit"])
		self.assertEqual(s["files_read"], [f"{p}/cart.js"])
		self.assertEqual(s["files_edited"], [f"{p}/cart.js", f"{p}/cart.test.js"])
		self.assertEqual(s["commits"], ["git commit -am 'fix: round when formatting'"])
		self.assertEqual(s["tool_usage"], {"skill": 1, "view": 1, "apply_patch": 1, "bash": 1})
		self.assertEqual(len(s["assistant_summaries"]), 1)

	def test_codex_session(self):
		[s] = self.sessions("--agent", "codex")
		p = str(self.project)
		self.assertEqual(s["agent"], "codex")
		self.assertEqual(s["session_id"], "codex-1")
		self.assertEqual(s["title"], "Add a discount option to cart.js")
		self.assertEqual(s["branch"], "feat/discounts")
		self.assertEqual(s["duration_minutes"], 7)
		# The environment block Codex sends as a user message is not a prompt.
		self.assertEqual(s["user_prompts"], ["Add a discount option to cart.js", "Stop, the discount should apply before tax instead"])
		self.assertEqual(s["corrections"], ["Stop, the discount should apply before tax instead"])
		self.assertEqual(s["skills_used"], ["commit"])
		self.assertEqual(s["files_read"], [f"{p}/.agents/skills/commit/SKILL.md", f"{p}/cart.js"])
		self.assertEqual(s["files_edited"], [f"{p}/cart.js"])
		self.assertEqual(s["commits"], ["git add cart.js && git commit -m 'feat: add discounts'"])
		self.assertEqual(s["tool_usage"], {"exec_command": 3, "apply_patch": 1})

	def test_every_agent_by_default_oldest_first(self):
		self.assertEqual([s["agent"] for s in self.sessions()], ["claude", "copilot", "codex"])

	def test_window_leaves_out_other_days(self):
		result = self.run_script("--date", "2026-11-05")
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(json.loads(result.stdout), [])

	def test_no_sessions_for_project(self):
		result = self.run_script(cwd=Path(self.tmp.name) / "nowhere")
		self.assertEqual(result.returncode, 1)
		error = json.loads(result.stdout)["error"]
		self.assertIn("claude (", error)
		self.assertIn("copilot (", error)
		self.assertIn("codex (", error)


if __name__ == "__main__":
	unittest.main(verbosity=2)
