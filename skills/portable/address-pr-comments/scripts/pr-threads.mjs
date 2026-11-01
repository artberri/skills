#!/usr/bin/env node
/**
 * pr-threads.mjs: fetch, reply to, and resolve GitHub PR review threads
 *
 * Usage:
 *   node pr-threads.mjs list <PR_NUMBER>               List unresolved threads
 *   node pr-threads.mjs resolve <THREAD_NODE_ID>       Resolve a thread
 *   node pr-threads.mjs reply <THREAD_NODE_ID> <body>  Reply to a thread
 *   node pr-threads.mjs local-list                     List open local OCR findings
 *   node pr-threads.mjs local-resolve <ID> <note>      Close a local OCR finding
 *
 * Local findings are the ones `ocr-review --local` saves for the current
 * branch in `$(git rev-parse --git-path ocr-review)/<branch>.json`, with the
 * branch name URL-encoded. The format is ocr-review's: see its
 * references/local-mode.md. Only `status` and `notes` are changed here.
 */

import { execFileSync, execSync } from 'node:child_process';
import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const GH_GRAPHQL = 'https://api.github.com/graphql';

function getToken() {
	try {
		return execSync('gh auth token', { encoding: 'utf8' }).trim();
	} catch {
		console.error('Error: gh CLI not authenticated. Run: gh auth login');
		process.exit(1);
	}
}

function getRepo() {
	try {
		const json = execSync('gh repo view --json owner,name', {
			encoding: 'utf8',
		});
		const { owner, name } = JSON.parse(json);
		return { owner: owner.login, name };
	} catch {
		console.error(
			'Error: could not determine repo. Run from inside a GitHub repo.',
		);
		process.exit(1);
	}
}

async function graphql(token, query, variables = {}) {
	const res = await fetch(GH_GRAPHQL, {
		method: 'POST',
		headers: {
			Authorization: `bearer ${token}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({ query, variables }),
	});
	const json = await res.json();
	if (json.errors) {
		console.error('GraphQL errors:', JSON.stringify(json.errors, null, 2));
		process.exit(1);
	}
	return json.data;
}

function indent(text) {
	return text.replace(/\r\n/g, '\n').trim().replace(/^/gm, '  ');
}

async function listThreads(prNumber) {
	const token = getToken();
	const { owner, name } = getRepo();

	const threads = [];
	let cursor = null;
	do {
		const data = await graphql(
			token,
			`
				query ($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
					repository(owner: $owner, name: $repo) {
						pullRequest(number: $pr) {
							reviewThreads(first: 100, after: $cursor) {
								pageInfo {
									hasNextPage
									endCursor
								}
								nodes {
									id
									isResolved
									isOutdated
									path
									line
									originalLine
									comments(first: 50) {
										nodes {
											databaseId
											author {
												login
											}
											body
										}
									}
								}
							}
						}
					}
				}
			`,
			{ owner, repo: name, pr: parseInt(prNumber, 10), cursor },
		);
		const page = data.repository.pullRequest.reviewThreads;
		threads.push(...page.nodes);
		cursor = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
	} while (cursor);

	const unresolved = threads.filter((t) => !t.isResolved);
	if (unresolved.length === 0) {
		console.log('No unresolved review threads.');
		return;
	}

	for (const thread of unresolved) {
		const [comment, ...replies] = thread.comments.nodes;
		const line = thread.line ?? thread.originalLine;
		const location = line === null ? thread.path : `${thread.path}:${line}`;
		const lines = [
			`THREAD_ID: ${thread.id}`,
			`COMMENT_ID: ${comment.databaseId}`,
			`FILE: ${location}${thread.isOutdated ? ' (outdated: the code has changed since)' : ''}`,
			`AUTHOR: ${comment.author?.login ?? 'unknown'}`,
			'BODY:',
			indent(comment.body),
		];
		for (const reply of replies) {
			lines.push(`REPLY from ${reply.author?.login ?? 'unknown'}:`, indent(reply.body));
		}
		lines.push('---');
		console.log(lines.join('\n'));
	}
}

async function resolveThread(threadId) {
	const token = getToken();
	const data = await graphql(
		token,
		`
			mutation ($threadId: ID!) {
				resolveReviewThread(input: { threadId: $threadId }) {
					thread {
						id
						isResolved
					}
				}
			}
		`,
		{ threadId },
	);

	const { id, isResolved } = data.resolveReviewThread.thread;
	console.log(JSON.stringify({ id, isResolved }));
}

async function replyToThread(threadId, body) {
	const token = getToken();
	const { owner, name } = getRepo();

	// Get the PR number and original comment ID for the thread
	const data = await graphql(
		token,
		`
			query ($threadId: ID!) {
				node(id: $threadId) {
					... on PullRequestReviewThread {
						pullRequest {
							number
						}
						comments(first: 1) {
							nodes {
								databaseId
							}
						}
					}
				}
			}
		`,
		{ threadId },
	);

	const prNumber = data.node.pullRequest.number;
	const inReplyTo = data.node.comments.nodes[0].databaseId;

	const res = await fetch(
		`https://api.github.com/repos/${owner}/${name}/pulls/${prNumber}/comments`,
		{
			method: 'POST',
			headers: {
				Authorization: `bearer ${token}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ body, in_reply_to: inReplyTo }),
		},
	);

	const json = await res.json();
	if (!res.ok) {
		console.error('Error posting reply:', JSON.stringify(json));
		process.exit(1);
	}
	console.log(JSON.stringify({ id: json.id, status: 'created' }));
}

function git(args) {
	return execFileSync('git', args, { encoding: 'utf8' }).trim();
}

function localStatePath() {
	let branch;
	try {
		branch = git(['symbolic-ref', '--short', '--quiet', 'HEAD']);
	} catch {
		console.error('Error: HEAD is detached. Check out the branch that was reviewed.');
		process.exit(1);
	}
	const directory = resolve(git(['rev-parse', '--git-path', 'ocr-review']));
	return `${directory}/${encodeURIComponent(branch)}.json`;
}

function readLocalState() {
	const path = localStatePath();
	try {
		return { path, state: JSON.parse(readFileSync(path, 'utf8')) };
	} catch (error) {
		if (error.code === 'ENOENT') {
			return { path, state: undefined };
		}
		throw error;
	}
}

// The same rule ocr-review applies before dropping a state: the reviewed commits are in the base, their changes are
// (a rebase before the push gives them new shas), or the branch has nothing left to ship.
function hasShipped(state) {
	try {
		execFileSync('git', ['merge-base', '--is-ancestor', state.lastReviewedSha, state.base], { stdio: 'ignore' });
		return true;
	} catch {
		// Not an ancestor, or the sha is gone: try the other checks.
	}
	try {
		const cherry = git(['cherry', state.base, state.lastReviewedSha, state.fromSha]);
		if (!cherry.split('\n').some((line) => line.startsWith('+'))) {
			return true;
		}
	} catch {
		// A sha that no longer exists can't be compared.
	}
	try {
		return git(['rev-list', '--count', `${state.base}..HEAD`]) === '0';
	} catch {
		return false;
	}
}

function listLocalFindings() {
	const { state } = readLocalState();
	if (state && hasShipped(state)) {
		console.log('The reviewed commits have already shipped: no open local OCR findings.');
		return;
	}
	const open = (state?.findings ?? []).filter((f) => f.status === 'open');
	if (open.length === 0) {
		console.log('No open local OCR findings.');
		return;
	}
	console.log(
		`Local OCR review of ${state.branch} at ${state.lastReviewedSha.slice(0, 10)}: confidence ${state.confidence}/5. ${state.confidenceReason}\n---`,
	);
	for (const finding of open) {
		const hasRange = finding.startLine !== undefined && finding.startLine < finding.line;
		const location = hasRange
			? `${finding.path}:${finding.startLine}-${finding.line}`
			: `${finding.path}:${finding.line}`;
		const lines = [
			`FINDING_ID: ${finding.id}`,
			`FILE: ${location}`,
			`SEVERITY: ${finding.severity} (${finding.category})`,
			`TITLE: ${finding.title}`,
			'BODY:',
			indent(finding.body),
		];
		if (finding.verification) {
			lines.push('VERIFIED BY:', indent(finding.verification));
		}
		if (finding.suggestion) {
			lines.push(`SUGGESTED REPLACEMENT for ${location}:`, indent(finding.suggestion));
		}
		for (const note of finding.notes) {
			lines.push(`NOTE from ${note.author}:`, indent(note.body));
		}
		lines.push('---');
		console.log(lines.join('\n'));
	}
}

function resolveLocalFinding(id, note) {
	const { path, state } = readLocalState();
	if (state && hasShipped(state)) {
		console.error('Error: the reviewed commits have already shipped, so their local findings are gone.');
		process.exit(1);
	}
	const finding = state?.findings.find((f) => f.id === id);
	if (!finding) {
		console.error(`Error: no local OCR finding #${id} on this branch.`);
		process.exit(1);
	}
	finding.status = 'closed';
	finding.notes.push({ author: 'address-pr-comments', body: note });
	writeFileSync(`${path}.tmp`, `${JSON.stringify(state, null, '\t')}\n`);
	renameSync(`${path}.tmp`, path);
	console.log(JSON.stringify({ id, status: 'closed' }));
}

const [, , command, ...args] = process.argv;

switch (command) {
	case 'list':
		if (!args[0]) {
			console.error('Usage: pr-threads.mjs list <PR_NUMBER>');
			process.exit(1);
		}
		await listThreads(args[0]);
		break;
	case 'resolve':
		if (!args[0]) {
			console.error('Usage: pr-threads.mjs resolve <THREAD_NODE_ID>');
			process.exit(1);
		}
		await resolveThread(args[0]);
		break;
	case 'reply':
		if (!args[0] || !args[1]) {
			console.error('Usage: pr-threads.mjs reply <THREAD_NODE_ID> "<body>"');
			process.exit(1);
		}
		await replyToThread(args[0], args.slice(1).join(' '));
		break;
	case 'local-list':
		listLocalFindings();
		break;
	case 'local-resolve':
		if (!args[0] || !args[1] || !Number.isInteger(Number(args[0]))) {
			console.error('Usage: pr-threads.mjs local-resolve <FINDING_ID> "<note>"');
			process.exit(1);
		}
		resolveLocalFinding(Number(args[0]), args.slice(1).join(' '));
		break;
	default:
		console.error('Unknown command. Use: list | resolve | reply | local-list | local-resolve');
		process.exit(1);
}
