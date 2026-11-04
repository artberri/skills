#!/usr/bin/env python3
"""Extract structured summaries from coding-agent session transcripts.

Usage:
	python3 extract_sessions.py --scope day [--date YYYY-MM-DD] [--cwd DIR] [--agent NAME]
	python3 extract_sessions.py --scope week [--date YYYY-MM-DD] [--days N] [--cwd DIR] [--agent NAME]

Reads one project's sessions from every agent that kept some, or only from
--agent:

	claude   Claude Code: $CLAUDE_CONFIG_DIR/projects (or ~/.claude/projects)
	codex    Codex: $CODEX_HOME/sessions (or ~/.codex/sessions)
	copilot  GitHub Copilot CLI: $COPILOT_HOME/session-state (or ~/.copilot/session-state)

Days are local days. Output: JSON array of session summaries to stdout, each
with an "agent" field, oldest first.
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
from typing import Callable, Iterator

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

# apply_patch arguments name each file they touch on a line like this.
PATCH_FILE = re.compile(r"^\*\*\* (?:Update|Add|Delete) File: (.+)$", re.MULTILINE)


def claude_dir() -> Path:
	return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude") / "projects"


def codex_dir() -> Path:
	return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "sessions"


def copilot_dir() -> Path:
	return Path(os.environ.get("COPILOT_HOME") or Path.home() / ".copilot") / "session-state"


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


def clean(text: str) -> str:
	return NOISE_PATTERNS.sub("", text).strip()


def is_correction(text: str) -> bool:
	cleaned = clean(text)
	if not cleaned or len(cleaned) < 10 or len(cleaned) > 500:
		return False
	return bool(CORRECTION_PATTERNS.search(cleaned))


def read_jsonl(path: Path) -> list[dict]:
	events = []
	try:
		with open(path, encoding="utf-8") as f:
			for line in f:
				try:
					event = json.loads(line)
				except json.JSONDecodeError:
					continue
				if isinstance(event, dict):
					events.append(event)
	except (OSError, UnicodeDecodeError):
		return []
	return events


class Session:
	"""Collects what one session did, whichever agent ran it, and turns it into
	the summary the retro reads. Readers feed it in the agent's own terms:
	tool names stay as the agent calls them in tool_usage, while reads, edits,
	commands and skills are counted the same way for every agent."""

	def __init__(self, agent: str, fallback_id: str):
		self.agent = agent
		self.session_id = fallback_id
		self.title = None
		self.branch = None
		self.first_ts = None
		self.last_ts = None
		self.user_prompts = []
		self.assistant_texts = []
		self.corrections = []
		self.tools = Counter()
		self.skills = set()
		self.files_edited = set()
		self.files_read = set()
		self.commits = []

	def seen_at(self, ts) -> None:
		ts = parse_timestamp(ts)
		if not ts:
			return
		if self.first_ts is None or ts < self.first_ts:
			self.first_ts = ts
		if self.last_ts is None or ts > self.last_ts:
			self.last_ts = ts

	def prompt(self, text: str) -> None:
		text = clean(text)
		if text and len(text) > 5:
			self.user_prompts.append(text[:500])
			if is_correction(text):
				self.corrections.append(text[:300])

	def reply(self, text: str) -> None:
		text = clean(text)
		if text:
			self.assistant_texts.append(text[:500])

	def tool(self, name: str) -> None:
		self.tools[name] += 1

	def command(self, cmd: str) -> None:
		if "git commit" in cmd:
			self.commits.append(cmd[:200])

	def summary(self) -> dict | None:
		if not self.user_prompts:
			return None
		duration = 0
		if self.first_ts and self.last_ts:
			duration = round((self.last_ts - self.first_ts).total_seconds() / 60)
		return {
			"agent": self.agent,
			"session_id": self.session_id,
			"title": self.title or self.user_prompts[0][:100],
			"branch": self.branch,
			"date": self.first_ts.isoformat() if self.first_ts else None,
			"duration_minutes": duration,
			"user_prompts": self.user_prompts[:20],
			"assistant_summaries": [t for t in self.assistant_texts if len(t) > 30][:15],
			"corrections": self.corrections,
			"skills_used": sorted(self.skills - {""}),
			"files_edited": sorted(self.files_edited - {""})[:30],
			"files_read": sorted(self.files_read - {""})[:30],
			"commits": self.commits,
			"tool_usage": dict(self.tools.most_common(10)),
			"prompt_count": len(self.user_prompts),
		}


# Claude Code


def claude_text(content) -> str:
	if isinstance(content, str):
		return content
	if isinstance(content, list):
		return "\n".join(
			b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"
		)
	return ""


def read_claude(path: Path) -> dict | None:
	s = Session("claude", path.stem)
	found_id = False
	for msg in read_jsonl(path):
		s.seen_at(msg.get("timestamp"))
		if not found_id and msg.get("sessionId"):
			s.session_id = msg["sessionId"]
			found_id = True
		if not s.branch and msg.get("gitBranch"):
			s.branch = msg["gitBranch"]

		kind = msg.get("type")
		content = msg.get("message", {})
		if isinstance(content, dict):
			content = content.get("content", "")

		if kind == "ai-title" and msg.get("aiTitle"):
			s.title = msg["aiTitle"]
		elif kind == "user":
			s.prompt(claude_text(content))
		elif kind == "assistant":
			s.reply(claude_text(content))
			for block in content if isinstance(content, list) else []:
				if not isinstance(block, dict) or block.get("type") != "tool_use":
					continue
				name = block.get("name", "unknown")
				inp = block.get("input") or {}
				s.tool(name)
				if name == "Skill":
					s.skills.add(inp.get("skill", ""))
				elif name in ("Edit", "Write"):
					s.files_edited.add(inp.get("file_path", ""))
				elif name == "Read":
					s.files_read.add(inp.get("file_path", ""))
				elif name == "Bash":
					s.command(str(inp.get("command", "")))
	return s.summary()


def claude_sessions(project: list[str]) -> Iterator[Path]:
	# Claude Code names a project's transcript folder after its path, with
	# every character other than a letter or digit replaced by "-".
	for path in project:
		folder = claude_dir() / re.sub(r"[^A-Za-z0-9]", "-", path)
		if folder.is_dir():
			yield from sorted(f for f in folder.iterdir() if f.name.endswith(".jsonl"))
			return


# GitHub Copilot CLI


def read_copilot(path: Path) -> dict | None:
	s = Session("copilot", path.parent.name)
	for event in read_jsonl(path):
		s.seen_at(event.get("timestamp"))
		kind = event.get("type")
		data = event.get("data") or {}

		if kind == "session.start":
			s.session_id = data.get("sessionId") or s.session_id
			s.branch = (data.get("context") or {}).get("branch") or s.branch
		elif kind == "session.title_changed" and data.get("title"):
			s.title = data["title"]
		elif kind == "user.message":
			s.prompt(str(data.get("content", "")))
		elif kind == "assistant.message":
			s.reply(str(data.get("content", "")))
		elif kind == "skill.invoked":
			s.skills.add(data.get("name", ""))
		elif kind == "tool.execution_start":
			name = data.get("toolName", "unknown")
			args = data.get("arguments")
			s.tool(name)
			if name == "bash" and isinstance(args, dict):
				s.command(str(args.get("command", "")))
			elif name == "view" and isinstance(args, dict):
				s.files_read.add(args.get("path", ""))
			elif name == "apply_patch" and isinstance(args, str):
				s.files_edited.update(PATCH_FILE.findall(args))
		elif kind == "tool.execution_complete":
			# Every editing tool reports the files it changed here.
			for edit in data.get("fileEdits") or []:
				if isinstance(edit, dict):
					s.files_edited.add(edit.get("path", ""))
	return s.summary()


def copilot_project(events_path: Path) -> list[str]:
	# Only the first lines are needed: session.start comes first.
	try:
		with open(events_path, encoding="utf-8") as f:
			for _, line in zip(range(20), f):
				try:
					event = json.loads(line)
				except json.JSONDecodeError:
					continue
				if isinstance(event, dict) and event.get("type") == "session.start":
					context = (event.get("data") or {}).get("context") or {}
					return [p for p in (context.get("cwd"), context.get("gitRoot")) if p]
	except (OSError, UnicodeDecodeError):
		pass
	return []


def copilot_sessions(project: list[str]) -> Iterator[Path]:
	folder = copilot_dir()
	if not folder.is_dir():
		return
	wanted = {os.path.realpath(p) for p in project}
	for session in sorted(folder.iterdir()):
		events = session / "events.jsonl"
		if events.is_file() and any(os.path.realpath(p) in wanted for p in copilot_project(events)):
			yield events


# Codex


def codex_text(content) -> str:
	if isinstance(content, list):
		return "\n".join(
			str(b.get("text", "")) for b in content if isinstance(b, dict) and str(b.get("type", "")).lower() in ("text", "input_text", "output_text")
		)
	return str(content or "")


def file_uri_path(uri: str) -> str:
	return uri[len("file://"):] if uri.startswith("file://") else uri


def read_codex(path: Path) -> dict | None:
	s = Session("codex", path.stem)
	# Codex records each finished step as an item_completed event: the user's
	# own messages (without the context Codex adds), its replies, the shell
	# commands it ran and the files its patch tool changed.
	fallback_prompts = []
	saw_user_item = False
	for event in read_jsonl(path):
		s.seen_at(event.get("timestamp"))
		kind = event.get("type")
		payload = event.get("payload") or {}

		if kind == "session_meta":
			s.session_id = payload.get("id") or s.session_id
			s.branch = (payload.get("git") or {}).get("branch") or s.branch
		elif kind == "response_item" and payload.get("type") == "message" and payload.get("role") == "user":
			# Only used if a session has no UserMessage items: skip the
			# environment and instruction blocks Codex sends as user messages.
			text = codex_text(payload.get("content"))
			if text and not text.lstrip().startswith(("<", "# AGENTS.md instructions")):
				fallback_prompts.append(text)
		elif kind == "event_msg" and payload.get("type") == "item_completed":
			item = payload.get("item") or {}
			item_type = item.get("type")
			if item_type == "UserMessage":
				saw_user_item = True
				s.prompt(codex_text(item.get("content")))
			elif item_type == "AgentMessage":
				s.reply(codex_text(item.get("content")))
			elif item_type == "CommandExecution":
				s.tool("exec_command")
				command = item.get("command")
				s.command(command[-1] if isinstance(command, list) and command else str(command or ""))
				cwd = file_uri_path(str(item.get("cwd") or ""))
				for parsed in item.get("parsed_cmd") or []:
					if isinstance(parsed, dict) and parsed.get("type") == "read" and parsed.get("path"):
						read = os.path.join(cwd, parsed["path"]) if cwd else parsed["path"]
						s.files_read.add(read)
						# Codex has no skill tool: it reads the skill's SKILL.md.
						if os.path.basename(read) == "SKILL.md":
							s.skills.add(os.path.basename(os.path.dirname(read)))
			elif item_type == "FileChange":
				s.tool("apply_patch")
				s.files_edited.update(str(p) for p in (item.get("changes") or {}))
			elif item_type:
				s.tool(item_type)
	if not saw_user_item:
		for text in fallback_prompts:
			s.prompt(text)
	return s.summary()


def codex_project(rollout: Path) -> str | None:
	# session_meta is the first line.
	try:
		with open(rollout, encoding="utf-8") as f:
			event = json.loads(f.readline() or "{}")
	except (OSError, UnicodeDecodeError, json.JSONDecodeError):
		return None
	if isinstance(event, dict) and event.get("type") == "session_meta":
		return (event.get("payload") or {}).get("cwd")
	return None


def codex_sessions(project: list[str]) -> Iterator[Path]:
	# Sessions are filed by date, sessions/YYYY/MM/DD/rollout-*.jsonl, for
	# every project together.
	folder = codex_dir()
	if not folder.is_dir():
		return
	wanted = {os.path.realpath(p) for p in project}
	for rollout in sorted(folder.glob("*/*/*/rollout-*.jsonl")):
		cwd = codex_project(rollout)
		if cwd and os.path.realpath(cwd) in wanted:
			yield rollout


# All agents

AGENTS: dict[str, tuple[Callable[[list[str]], Iterator[Path]], Callable[[Path], dict | None], Callable[[], Path]]] = {
	"claude": (claude_sessions, read_claude, claude_dir),
	"codex": (codex_sessions, read_codex, codex_dir),
	"copilot": (copilot_sessions, read_copilot, copilot_dir),
}


def window(scope: str, target_date: datetime, days: int | None) -> tuple[datetime, datetime]:
	day_start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
	start = day_start if scope == "day" else day_start - timedelta(days=(days or 7) - 1)
	end = day_start + timedelta(days=1)
	return start.astimezone(timezone.utc), end.astimezone(timezone.utc)


def collect(agents: list[str], cwd: str, start: datetime, end: datetime) -> tuple[list[dict], bool]:
	# Try the path as given and with symlinks resolved (/tmp vs /private/tmp).
	project = list(dict.fromkeys([cwd, os.path.realpath(cwd)]))
	results = []
	found_any = False
	for agent in agents:
		find, read, _ = AGENTS[agent]
		for path in find(project):
			found_any = True
			# Cheap pre-filter on the file's modification time before parsing it.
			if datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc) < start - timedelta(days=1):
				continue
			session = read(path)
			if not session or not session["date"]:
				continue
			session_dt = parse_timestamp(session["date"])
			if session_dt and start <= session_dt < end:
				results.append(session)
	results.sort(key=lambda s: s["date"] or "")
	return results, found_any


def main():
	parser = argparse.ArgumentParser(description="Extract coding-agent session summaries")
	parser.add_argument("--scope", choices=["day", "week"], required=True)
	parser.add_argument("--date", help="Last day of the window, YYYY-MM-DD in local time (default: today)")
	parser.add_argument("--days", type=int, help="Window size in days for scope=week (default: 7)")
	parser.add_argument("--cwd", default=os.getcwd(), help="Project working directory (default: the current one)")
	parser.add_argument("--agent", choices=sorted(AGENTS), help="Read only this agent's sessions (default: every agent)")
	parser.add_argument("--compact", action="store_true", help="Compact JSON output")
	args = parser.parse_args()

	# Local days, so "today" means the user's today, not UTC's.
	target_date = datetime.now().astimezone()
	if args.date:
		target_date = datetime.strptime(args.date, "%Y-%m-%d").astimezone()

	agents = [args.agent] if args.agent else sorted(AGENTS)
	start, end = window(args.scope, target_date, args.days)
	sessions, found_any = collect(agents, args.cwd, start, end)
	if not found_any:
		looked = ", ".join(f"{a} ({AGENTS[a][2]()})" for a in agents)
		print(json.dumps({
			"error": f"No sessions for {args.cwd} from {looked}. Run from the project's root, or pass --cwd.",
		}))
		sys.exit(1)

	indent = None if args.compact else 2
	print(json.dumps(sessions, indent=indent, default=str))


if __name__ == "__main__":
	main()
