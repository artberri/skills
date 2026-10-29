#!/usr/bin/env python3
"""Extract structured summaries from Claude Code session transcripts.

Usage:
	python3 extract_sessions.py --scope day [--date YYYY-MM-DD] [--cwd DIR]
	python3 extract_sessions.py --scope week [--date YYYY-MM-DD] [--days N] [--cwd DIR]

Reads the transcripts of one project from $CLAUDE_CONFIG_DIR/projects (or
~/.claude/projects). Days are local days. Output: JSON array of session
summaries to stdout.
"""

# Keeps the type hints below working on Python 3.9, macOS's /usr/bin/python3.
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
TRANSCRIPTS_DIR = CONFIG_DIR / "projects"

CORRECTION_PATTERNS = re.compile(
	r"\b(no[,.]?\s+(not|don't|instead|wrong|that's not|actually))"
	r"|\b(don't|do not|stop|never|shouldn't|should not)\b"
	r"|\b(instead|rather|actually|wrong|incorrect|fix|undo|revert)\b"
	r"|\bnot like that\b"
	r"|\bthat's wrong\b"
	r"|\btry again\b",
	re.IGNORECASE,
)

NOISE_PATTERNS = re.compile(
	r"<system-reminder>.*?</system-reminder>"
	r"|<task-notification>.*?</task-notification>"
	r"|<local-command-caveat>.*?</local-command-caveat>"
	r"|<local-command-.*?>"
	r"|<command-name>.*?</command-name>"
	r"|<command-message>.*?</command-message>"
	r"|<command-args>.*?</command-args>"
	r"|<local-command-stdout>.*?</local-command-stdout>",
	re.DOTALL,
)


def project_key(path: str) -> str:
	# Claude Code names a project's transcript folder after its path, with
	# every character other than a letter or digit replaced by "-".
	return re.sub(r"[^A-Za-z0-9]", "-", path)


def find_project_dir(cwd: str) -> Path | None:
	# Try the path as given and with symlinks resolved (/tmp vs /private/tmp).
	for path in (cwd, os.path.realpath(cwd)):
		candidate = TRANSCRIPTS_DIR / project_key(path)
		if candidate.is_dir():
			return candidate
	return None


def parse_timestamp(ts) -> datetime | None:
	if ts is None:
		return None
	if isinstance(ts, str):
		try:
			return datetime.fromisoformat(ts.replace("Z", "+00:00"))
		except ValueError:
			return None
	if isinstance(ts, (int, float)):
		return datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
	return None


def extract_text_from_content(content) -> str:
	if isinstance(content, str):
		return NOISE_PATTERNS.sub("", content).strip()
	if isinstance(content, list):
		parts = []
		for block in content:
			if isinstance(block, dict) and block.get("type") == "text":
				text = block.get("text", "")
				text = NOISE_PATTERNS.sub("", text).strip()
				if text:
					parts.append(text)
		return "\n".join(parts)
	return ""


def extract_tool_uses(content) -> list[dict]:
	tools = []
	if not isinstance(content, list):
		return tools
	for block in content:
		if isinstance(block, dict) and block.get("type") == "tool_use":
			name = block.get("name", "unknown")
			tool_info = {"name": name}
			inp = block.get("input", {})
			if name == "Bash":
				tool_info["command"] = str(inp.get("command", ""))[:200]
			elif name in ("Edit", "Write", "Read"):
				tool_info["file"] = inp.get("file_path", "")
			elif name == "Skill":
				tool_info["skill"] = inp.get("skill", "")
			elif name == "Agent":
				tool_info["description"] = inp.get("description", "")
				tool_info["subagent_type"] = inp.get("subagent_type", "")
			tools.append(tool_info)
	return tools


def is_correction(text: str) -> bool:
	cleaned = NOISE_PATTERNS.sub("", text).strip()
	if not cleaned or len(cleaned) < 10 or len(cleaned) > 500:
		return False
	return bool(CORRECTION_PATTERNS.search(cleaned))


def extract_session(jsonl_path: Path) -> dict | None:
	messages = []
	try:
		with open(jsonl_path, encoding="utf-8") as f:
			for line in f:
				try:
					messages.append(json.loads(line))
				except json.JSONDecodeError:
					continue
	except (OSError, UnicodeDecodeError):
		return None

	if not messages:
		return None

	session_id = None
	title = None
	branch = None
	first_ts = None
	last_ts = None
	user_prompts = []
	assistant_texts = []
	tool_uses = []
	corrections = []
	skills_used = set()
	files_edited = set()
	files_read = set()
	commits = []

	for msg in messages:
		if not isinstance(msg, dict):
			continue
		ts = parse_timestamp(msg.get("timestamp"))
		if ts:
			if first_ts is None or ts < first_ts:
				first_ts = ts
			if last_ts is None or ts > last_ts:
				last_ts = ts

		if not session_id:
			session_id = msg.get("sessionId")
		if not branch and msg.get("gitBranch"):
			branch = msg["gitBranch"]

		msg_type = msg.get("type")

		if msg_type == "ai-title" and msg.get("aiTitle"):
			title = msg["aiTitle"]

		elif msg_type == "user":
			content = msg.get("message", {})
			if isinstance(content, dict):
				content = content.get("content", "")
			text = extract_text_from_content(content)
			if text and len(text) > 5:
				user_prompts.append(text[:500])
				if is_correction(text):
					corrections.append(text[:300])

		elif msg_type == "assistant":
			content = msg.get("message", {})
			if isinstance(content, dict):
				content = content.get("content", [])
			text = extract_text_from_content(content)
			if text:
				assistant_texts.append(text[:500])

			for t in extract_tool_uses(content):
				tool_uses.append(t)
				if t["name"] == "Skill":
					skills_used.add(t.get("skill", ""))
				elif t["name"] in ("Edit", "Write"):
					if t.get("file"):
						files_edited.add(t["file"])
				elif t["name"] == "Read":
					if t.get("file"):
						files_read.add(t["file"])
				elif t["name"] == "Bash":
					cmd = t.get("command", "")
					if "git commit" in cmd:
						commits.append(cmd[:200])

	if not user_prompts:
		return None

	duration_min = 0
	if first_ts and last_ts:
		duration_min = round((last_ts - first_ts).total_seconds() / 60)

	if not title:
		title = user_prompts[0][:100]

	return {
		"session_id": session_id or jsonl_path.stem,
		"title": title,
		"branch": branch,
		"date": first_ts.isoformat() if first_ts else None,
		"duration_minutes": duration_min,
		"user_prompts": user_prompts[:20],
		"assistant_summaries": [t for t in assistant_texts if len(t) > 30][:15],
		"corrections": corrections,
		"skills_used": sorted(skills_used - {""}),
		"files_edited": sorted(files_edited)[:30],
		"files_read": sorted(files_read)[:30],
		"commits": commits,
		"tool_usage": dict(Counter(t["name"] for t in tool_uses).most_common(10)),
		"prompt_count": len(user_prompts),
	}


def get_sessions_for_scope(project_dir: Path, scope: str, target_date: datetime, days_override: int | None = None) -> list[dict]:
	day_start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
	if scope == "day":
		start = day_start
	else:
		start = day_start - timedelta(days=(days_override or 7) - 1)
	end = day_start + timedelta(days=1)
	start_utc = start.astimezone(timezone.utc)
	end_utc = end.astimezone(timezone.utc)

	results = []
	for f in sorted(project_dir.iterdir()):
		if not f.name.endswith(".jsonl"):
			continue
		# Cheap pre-filter on the file's modification time before parsing it.
		file_mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
		if file_mtime < start_utc - timedelta(days=1):
			continue

		session = extract_session(f)
		if not session or not session["date"]:
			continue

		session_dt = parse_timestamp(session["date"])
		if session_dt and start_utc <= session_dt < end_utc:
			results.append(session)

	results.sort(key=lambda s: s["date"] or "")
	return results


def main():
	parser = argparse.ArgumentParser(description="Extract Claude Code session summaries")
	parser.add_argument("--scope", choices=["day", "week"], required=True)
	parser.add_argument("--date", help="Last day of the window, YYYY-MM-DD in local time (default: today)")
	parser.add_argument("--days", type=int, help="Window size in days for scope=week (default: 7)")
	parser.add_argument("--cwd", default=os.getcwd(), help="Project working directory (default: the current one)")
	parser.add_argument("--compact", action="store_true", help="Compact JSON output")
	args = parser.parse_args()

	# Local days, so "today" means the user's today, not UTC's.
	target_date = datetime.now().astimezone()
	if args.date:
		target_date = datetime.strptime(args.date, "%Y-%m-%d").astimezone()

	project_dir = find_project_dir(args.cwd)
	if not project_dir:
		print(json.dumps({
			"error": f"No transcripts for {args.cwd} in {TRANSCRIPTS_DIR}. Run from the project's root, or pass --cwd.",
		}))
		sys.exit(1)

	sessions = get_sessions_for_scope(project_dir, args.scope, target_date, args.days)

	indent = None if args.compact else 2
	print(json.dumps(sessions, indent=indent, default=str))


if __name__ == "__main__":
	main()
