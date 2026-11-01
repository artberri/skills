import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

// The marker is how the git-push hook and incremental reviews find the last commit this tool reviewed.
const REVIEW_MARKER_PREFIX = "<!-- ocr-review reviewed-sha=";
const REVIEW_FOOTER_PATTERN = /<!-- ocr-review reviewed-sha=([0-9a-f]{40}) -->$/;
// GitHub has failed batches above ~70 inline comments; the rest go to the review body.
const MAX_INLINE_COMMENTS = 50;
// The whole-PR verdict lives in the PR body, like other review bots', so it can be rewritten as findings get fixed.
const PR_BODY_BLOCK_START = "<!-- ocr_comment -->";
const PR_BODY_BLOCK_END = "<!-- /ocr_comment -->";
// Only markers on a line of their own count: a PR description can mention them in backticks.
const OCR_BLOCK_PATTERN = /^<!-- ocr_comment -->\r?$[\s\S]*?^<!-- \/ocr_comment -->\r?$/m;
const BLOCK_SUMMARY_PATTERN = /<details open><summary>Summary<\/summary>\n\n([\s\S]*?)\n\n<\/details>/;
// File-level comments aren't part of the review, so their body carries the marker that identifies them as OCR's.
const FINDING_MARKER = "<!-- ocr-finding -->";
// Findings posted before FINDING_MARKER existed start with the severity label.
const LEGACY_FINDING_HEADING_PATTERN = /^(🔴 Critical|🟠 High|🟡 Medium) · /;

const Severity = {
	Critical: "critical",
	High: "high",
	Medium: "medium",
} as const;
type Severity = (typeof Severity)[keyof typeof Severity];

const PriorFindingStatus = {
	Closed: "closed",
	Open: "open",
} as const;
type PriorFindingStatus = (typeof PriorFindingStatus)[keyof typeof PriorFindingStatus];

interface Finding {
	path: string;
	line: number;
	startLine?: number;
	severity: Severity;
	category: string;
	title: string;
	body: string;
	verification?: string;
	suggestion?: string;
}

interface PriorFindingVerdict {
	commentId: number;
	status: PriorFindingStatus;
}

interface ReviewInput {
	// Absent on a local review.
	pr?: number;
	headSha: string;
	fromSha: string;
	confidence: number;
	confidenceReason: string;
	summary: string;
	prConfidence?: number;
	prConfidenceReason?: string;
	prSummary?: string;
	priorFindings?: PriorFindingVerdict[];
	checked?: string[];
	findings: Finding[];
}

interface PullRequestFile {
	filename: string;
	patch?: string;
}

interface InlineComment {
	path: string;
	line: number;
	side: "RIGHT";
	start_line?: number;
	start_side?: "RIGHT";
	body: string;
}

interface Review {
	body: string;
	commit_id: string;
	user: { login: string } | null;
}

interface PostedComment {
	body: string;
	html_url: string;
}

interface ThreadComment {
	databaseId: number;
	url: string;
	body: string;
	author: { login: string } | null;
}

interface ReviewThread {
	isResolved: boolean;
	path: string;
	line: number | null;
	comments: { nodes: ThreadComment[] };
}

interface ReviewThreadsPage {
	data: { repository: { pullRequest: { reviewThreads: { nodes: ReviewThread[] } } } };
}

interface PriorFinding {
	commentId: number;
	url: string;
	path: string;
	line: number | null;
	body: string;
	replies: { author: string; body: string }[];
}

interface OpenFinding {
	heading: string;
	url: string;
	location: string;
}

// A local review keeps its state in the git dir, one file per branch: never committed, never on GitHub.
// address-pr-comments reads and updates the same file; references/local-mode.md documents the format.
const LocalFindingStatus = {
	Open: "open",
	Closed: "closed",
} as const;
type LocalFindingStatus = (typeof LocalFindingStatus)[keyof typeof LocalFindingStatus];

interface LocalNote {
	author: string;
	body: string;
}

interface LocalFinding extends Finding {
	id: number;
	status: LocalFindingStatus;
	raisedAt: string;
	notes: LocalNote[];
}

interface LocalState {
	version: 1;
	branch: string;
	base: string;
	lastReviewedSha: string;
	fromSha: string;
	confidence: number;
	confidenceReason: string;
	summary: string;
	nextId: number;
	findings: LocalFinding[];
}

function gh(args: string[], input?: string): string {
	return execFileSync("gh", args, { encoding: "utf8", input, maxBuffer: 64 * 1024 * 1024 });
}

function git(args: string[]): string {
	return execFileSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 }).trim();
}

function gitSucceeds(args: string[]): boolean {
	try {
		execFileSync("git", args, { stdio: "ignore" });
		return true;
	} catch {
		return false;
	}
}

function repoNameWithOwner(): string {
	return gh(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).trim();
}

function commentableLinesFromPatch(patch: string): Set<number> {
	const lines = new Set<number>();
	let rightLine = 0;
	for (const patchLine of patch.split("\n")) {
		const hunkHeader = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(patchLine);
		if (hunkHeader) {
			rightLine = Number(hunkHeader[1]);
			continue;
		}
		if (patchLine.startsWith("-") || patchLine.startsWith("\\")) {
			continue;
		}
		lines.add(rightLine);
		rightLine++;
	}
	return lines;
}

function commentableLinesByPath(repo: string, pr: number): Map<string, Set<number>> {
	const pages = JSON.parse(
		gh(["api", "--paginate", "--slurp", `repos/${repo}/pulls/${pr}/files?per_page=100`]),
	) as PullRequestFile[][];
	return new Map(pages.flat().map((file) => [file.filename, commentableLinesFromPatch(file.patch ?? "")] as const));
}

function isRangeCommentable(lines: Set<number>, startLine: number, endLine: number): boolean {
	for (let line = startLine; line <= endLine; line++) {
		if (!lines.has(line)) {
			return false;
		}
	}
	return true;
}

function severityLabel(severity: Severity): string {
	switch (severity) {
		case Severity.Critical:
			return "🔴 Critical";
		case Severity.High:
			return "🟠 High";
		case Severity.Medium:
			return "🟡 Medium";
	}
}

function findingHeading(finding: Finding): string {
	return `${severityLabel(finding.severity)} · \`${finding.category}\` · **${finding.title}**`;
}

function formatFindingBody(finding: Finding): string {
	return [
		findingHeading(finding),
		finding.body,
		finding.verification === undefined ? undefined : `**How this was verified:** ${finding.verification}`,
		finding.suggestion === undefined ? undefined : `\`\`\`suggestion\n${finding.suggestion}\n\`\`\``,
		FINDING_MARKER,
	]
		.filter((section) => section !== undefined)
		.join("\n\n");
}

function toInlineComment(finding: Finding, commentableLines: Set<number>): InlineComment | undefined {
	if (!commentableLines.has(finding.line)) {
		return undefined;
	}
	const comment: InlineComment = {
		path: finding.path,
		line: finding.line,
		side: "RIGHT",
		body: formatFindingBody(finding),
	};
	const hasValidRange =
		finding.startLine !== undefined &&
		finding.startLine < finding.line &&
		isRangeCommentable(commentableLines, finding.startLine, finding.line);
	if (hasValidRange) {
		return { ...comment, start_line: finding.startLine, start_side: "RIGHT" };
	}
	// A suggestion written for a multi-line range would replace only the last line.
	return finding.startLine === undefined
		? comment
		: { ...comment, body: formatFindingBody({ ...finding, suggestion: undefined }) };
}

// A file-level comment can't point at a line or apply a suggestion, so it names the line instead.
function formatFileLevelBody(finding: Finding): string {
	return formatFindingBody({
		...finding,
		body: `At line ${finding.line}, outside this PR's diff.\n\n${finding.body}`,
		suggestion: undefined,
	});
}

function formatReviewBody(
	input: ReviewInput,
	counts: { inline: number; fileLevel: number },
	outsidePullRequest: Finding[],
	isIncremental: boolean,
): string {
	const checkedSection =
		input.checked === undefined || input.checked.length === 0
			? undefined
			: `Checked (not exhaustive):\n\n${input.checked.map((item) => `- ${item}`).join("\n")}`;
	const outsidePullRequestSection =
		outsidePullRequest.length === 0
			? undefined
			: `### Findings in files this PR doesn't change\n\n${outsidePullRequest
				  .map((finding) => `#### \`${finding.path}:${finding.line}\`\n\n${formatFindingBody(finding)}`)
				  .join("\n\n---\n\n")}`;
	const totalFindings = counts.inline + counts.fileLevel + outsidePullRequest.length;
	const countsLine =
		totalFindings === 0
			? "No findings."
			: `${totalFindings} finding(s): ${counts.inline} inline, ${counts.fileLevel} on a file, ${outsidePullRequest.length} in this body.`;
	return [
		"## 🤖 OCR review",
		`### Confidence score${isIncremental ? " (new commits only)" : ""}: ${input.confidence}/5`,
		input.confidenceReason,
		checkedSection,
		`<details open><summary>Summary</summary>\n\n${input.summary}\n\n</details>`,
		outsidePullRequestSection,
		`<sub>Reviewed \`${input.fromSha.slice(0, 10)}..${input.headSha.slice(0, 10)}\` with Claude Code in OCR delegation mode. ${countsLine}</sub>`,
	]
		.filter((section) => section !== undefined)
		.join("\n\n");
}

function withReviewedMarker(reviewBody: string, headSha: string): string {
	return `${reviewBody}\n\n${REVIEW_MARKER_PREFIX}${headSha} -->`;
}

function assertPullRequestHeadIs(repo: string, pr: number, headSha: string): void {
	const remoteHead = gh(["api", `repos/${repo}/pulls/${pr}`, "--jq", ".head.sha"]).trim();
	if (remoteHead !== headSha) {
		throw new Error(
			`PR #${pr} head is ${remoteHead} but the review covers ${headSha}. Push first, or review the PR head.`,
		);
	}
}

// A review range starting anywhere but the merge base covers only the commits since an earlier review.
function isIncrementalRange(repo: string, pr: number, input: ReviewInput): boolean {
	const baseRef = gh(["api", `repos/${repo}/pulls/${pr}`, "--jq", ".base.ref"]).trim();
	const mergeBase = gh([
		"api",
		`repos/${repo}/compare/${baseRef}...${input.headSha}`,
		"--jq",
		".merge_base_commit.sha",
	]).trim();
	return input.fromSha !== mergeBase;
}

function assertConfidenceIsValid(name: string, confidence: number): void {
	if (!Number.isInteger(confidence) || confidence < 1 || confidence > 5) {
		throw new Error(`${name} must be an integer from 1 to 5, got ${String(confidence)}.`);
	}
}

function pullRequestBody(repo: string, pr: number): string {
	return gh(["api", `repos/${repo}/pulls/${pr}`, "--jq", '.body // ""']).replace(/\n$/, "");
}

function ocrBlockOf(body: string): string | undefined {
	return OCR_BLOCK_PATTERN.exec(body)?.[0];
}

// Everything outside the OCR block, other bots' blocks and the author's text included, is kept as it is.
function withOcrBlock(body: string, block: string): string {
	const existingBlock = ocrBlockOf(body);
	if (existingBlock !== undefined) {
		return body.replace(existingBlock, () => block);
	}
	return body.trim() === "" ? block : `${body.trimEnd()}\n\n${block}`;
}

function ocrReviews(repo: string, pr: number): Review[] {
	const pages = JSON.parse(
		gh(["api", "--paginate", "--slurp", `repos/${repo}/pulls/${pr}/reviews?per_page=100`]),
	) as Review[][];
	// A review that quotes an older OCR body carries its marker too; only the footer of the review posted on that sha counts.
	return pages.flat().filter((review) => REVIEW_FOOTER_PATTERN.exec(review.body)?.[1] === review.commit_id);
}

// The markers are public text anyone can paste, so a finding also has to come from an account that posts OCR reviews.
function ocrPosterLogins(repo: string, pr: number): Set<string> {
	const currentLogin = gh(["api", "user", "--jq", ".login"]).trim();
	return new Set([
		currentLogin,
		...ocrReviews(repo, pr).flatMap((review) => (review.user ? [review.user.login] : [])),
	]);
}

function isOcrFinding(comment: ThreadComment, posterLogins: Set<string>): boolean {
	const hasOcrShape = comment.body.includes(FINDING_MARKER) || LEGACY_FINDING_HEADING_PATTERN.test(comment.body);
	return hasOcrShape && comment.author !== null && posterLogins.has(comment.author.login);
}

function readOpenPriorFindings(repo: string, pr: number): PriorFinding[] {
	const posterLogins = ocrPosterLogins(repo, pr);
	const [owner, name] = repo.split("/");
	if (owner === undefined || name === undefined) {
		throw new Error(`Unexpected repository name ${repo}.`);
	}
	const query = `query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
		repository(owner: $owner, name: $name) {
			pullRequest(number: $pr) {
				reviewThreads(first: 100, after: $endCursor) {
					pageInfo { hasNextPage endCursor }
					nodes {
						isResolved
						path
						line
						comments(first: 50) { nodes { databaseId url body author { login } } }
					}
				}
			}
		}
	}`;
	const pages = JSON.parse(
		gh([
			"api",
			"graphql",
			"--paginate",
			"--slurp",
			"-f",
			`query=${query}`,
			"-F",
			`owner=${owner}`,
			"-F",
			`name=${name}`,
			"-F",
			`pr=${pr}`,
		]),
	) as ReviewThreadsPage[];
	return pages
		.flatMap((page) => page.data.repository.pullRequest.reviewThreads.nodes)
		.flatMap((thread) => {
			const [first, ...replies] = thread.comments.nodes;
			if (!first || thread.isResolved || !isOcrFinding(first, posterLogins)) {
				return [];
			}
			return [
				{
					commentId: first.databaseId,
					url: first.url,
					path: thread.path,
					line: thread.line,
					body: first.body.replace(FINDING_MARKER, "").trim(),
					replies: replies.map((reply) => ({ author: reply.author?.login ?? "unknown", body: reply.body })),
				},
			];
		});
}

function printReviewState(pr: number): void {
	const repo = repoNameWithOwner();
	const block = ocrBlockOf(pullRequestBody(repo, pr));
	const summary = block === undefined ? undefined : BLOCK_SUMMARY_PATTERN.exec(block)?.[1];
	console.log(JSON.stringify({ summary, openFindings: readOpenPriorFindings(repo, pr) }, null, 2));
}

function priorFindingAsOpen(finding: PriorFinding): OpenFinding {
	return {
		heading: finding.body.split("\n")[0] ?? "",
		url: finding.url,
		location: finding.line === null ? finding.path : `${finding.path}:${finding.line}`,
	};
}

function formatPullRequestBlock(
	input: ReviewInput,
	verdict: { confidence: number; reason: string; summary: string },
	openFindings: OpenFinding[],
	reviewUrl: string,
): string {
	const openFindingsSection =
		openFindings.length === 0
			? "No open findings."
			: `### Open findings (${openFindings.length})\n\n${openFindings
				  .map((finding) => `- ${finding.heading} · [view](${finding.url}) · \`${finding.location}\``)
				  .join("\n")}`;
	return [
		PR_BODY_BLOCK_START,
		"## 🤖 OCR review",
		`### Confidence score: ${verdict.confidence}/5`,
		verdict.reason,
		`<details open><summary>Summary</summary>\n\n${verdict.summary}\n\n</details>`,
		openFindingsSection,
		`<sub>Last reviewed commit: \`${input.headSha.slice(0, 10)}\` · [latest review](${reviewUrl})</sub>`,
		PR_BODY_BLOCK_END,
	].join("\n\n");
}

function pullRequestVerdict(
	input: ReviewInput,
	isIncremental: boolean,
): { confidence: number; reason: string; summary: string } {
	if (!isIncremental) {
		return {
			confidence: input.prConfidence ?? input.confidence,
			reason: input.prConfidenceReason ?? input.confidenceReason,
			summary: input.prSummary ?? input.summary,
		};
	}
	if (
		input.prConfidence === undefined ||
		input.prConfidenceReason === undefined ||
		input.prSummary === undefined ||
		input.priorFindings === undefined
	) {
		throw new Error(
			"An incremental review needs prConfidence, prConfidenceReason, prSummary and priorFindings for the whole-change verdict.",
		);
	}
	return { confidence: input.prConfidence, reason: input.prConfidenceReason, summary: input.prSummary };
}

function postReview(inputPath: string, isDryRun: boolean): void {
	const input = JSON.parse(readFileSync(inputPath, "utf8")) as ReviewInput;
	assertConfidenceIsValid("confidence", input.confidence);
	if (input.pr === undefined) {
		throw new Error("The reply has no `pr`: post a review of local commits with --local.");
	}
	const pr = input.pr;
	const repo = repoNameWithOwner();
	assertPullRequestHeadIs(repo, pr, input.headSha);
	const isIncremental = isIncrementalRange(repo, pr, input);
	const verdict = pullRequestVerdict(input, isIncremental);
	assertConfidenceIsValid("prConfidence", verdict.confidence);
	const linesByPath = commentableLinesByPath(repo, pr);
	const priorFindings = readOpenPriorFindings(repo, pr);
	if (priorFindings.length > 0 && input.priorFindings === undefined) {
		throw new Error(
			`PR #${pr} has ${priorFindings.length} unresolved OCR finding(s): pass review-state to the reviewer and post its priorFindings.`,
		);
	}

	const inlineComments: InlineComment[] = [];
	const fileLevelFindings: Finding[] = [];
	const outsidePullRequest: Finding[] = [];
	for (const finding of input.findings) {
		const lines = linesByPath.get(finding.path);
		if (!lines) {
			outsidePullRequest.push(finding);
			continue;
		}
		const comment = inlineComments.length >= MAX_INLINE_COMMENTS ? undefined : toInlineComment(finding, lines);
		if (comment) {
			inlineComments.push(comment);
		} else {
			fileLevelFindings.push(finding);
		}
	}

	const review = {
		commit_id: input.headSha,
		event: "COMMENT",
		body: formatReviewBody(
			input,
			{ inline: inlineComments.length, fileLevel: fileLevelFindings.length },
			outsidePullRequest,
			isIncremental,
		),
		comments: inlineComments,
	};
	const fileLevelComments = fileLevelFindings.map((finding) => ({
		commit_id: input.headSha,
		path: finding.path,
		subject_type: "file",
		body: formatFileLevelBody(finding),
	}));
	const closedCommentIds = new Set(
		(input.priorFindings ?? [])
			.filter((prior) => prior.status === PriorFindingStatus.Closed)
			.map((prior) => prior.commentId),
	);
	const stillOpenPriorFindings = priorFindings
		.filter((prior) => !closedCommentIds.has(prior.commentId))
		.map(priorFindingAsOpen);

	if (isDryRun) {
		const newFindings = input.findings.map((finding) => ({
			heading: findingHeading(finding),
			url: "<new>",
			location: `${finding.path}:${finding.line}`,
		}));
		const reviewWithMarker = { ...review, body: withReviewedMarker(review.body, input.headSha) };
		console.log(JSON.stringify({ review: reviewWithMarker, fileLevelComments }, null, 2));
		console.log(formatPullRequestBlock(input, verdict, [...stillOpenPriorFindings, ...newFindings], "<new>"));
		return;
	}

	const posted = JSON.parse(
		gh(
			["api", "--method", "POST", `repos/${repo}/pulls/${pr}/reviews`, "--input", "-"],
			JSON.stringify(review),
		),
	) as { id: number; html_url: string };
	const postedInline = JSON.parse(
		gh(["api", "--paginate", "--slurp", `repos/${repo}/pulls/${pr}/reviews/${posted.id}/comments`]),
	) as PostedComment[][];
	const postedFileLevel = fileLevelComments.map(
		(comment) =>
			JSON.parse(
				gh(
					["api", "--method", "POST", `repos/${repo}/pulls/${pr}/comments`, "--input", "-"],
					JSON.stringify(comment),
				),
			) as PostedComment,
	);
	const postedUrlByBody = new Map(
		[...postedInline.flat(), ...postedFileLevel].map((comment) => [comment.body, comment.html_url] as const),
	);
	const newOpenFindings = [
		...inlineComments.map((comment) => ({
			body: comment.body,
			heading: comment.body.split("\n")[0] ?? "",
			location: `${comment.path}:${comment.line}`,
		})),
		...fileLevelComments.map((comment) => ({
			body: comment.body,
			heading: comment.body.split("\n")[0] ?? "",
			location: comment.path,
		})),
	].map((finding) => ({
		heading: finding.heading,
		url: postedUrlByBody.get(finding.body) ?? posted.html_url,
		location: finding.location,
	}));
	const outsidePullRequestFindings = outsidePullRequest.map((finding) => ({
		heading: findingHeading(finding),
		url: posted.html_url,
		location: `${finding.path}:${finding.line}`,
	}));

	// Read the body as late as possible: other review bots may rewrite their own blocks in it.
	const block = formatPullRequestBlock(
		input,
		verdict,
		[...stillOpenPriorFindings, ...newOpenFindings, ...outsidePullRequestFindings],
		posted.html_url,
	);
	gh(
		["api", "--method", "PATCH", `repos/${repo}/pulls/${pr}`, "--input", "-"],
		JSON.stringify({ body: withOcrBlock(pullRequestBody(repo, pr), block) }),
	);
	// The marker goes on last: until every write above succeeds, the next run must not treat this head as reviewed.
	gh(
		["api", "--method", "PUT", `repos/${repo}/pulls/${pr}/reviews/${posted.id}`, "--input", "-"],
		JSON.stringify({ body: withReviewedMarker(review.body, input.headSha) }),
	);
	console.log(posted.html_url);
}

function printLastReviewedSha(pr: number): void {
	const lastReviewedSha = ocrReviews(repoNameWithOwner(), pr).at(-1)?.commit_id;
	if (lastReviewedSha !== undefined) {
		console.log(lastReviewedSha);
	}
}

function currentBranch(): string {
	if (!gitSucceeds(["symbolic-ref", "--quiet", "HEAD"])) {
		throw new Error("HEAD is detached: check out a branch before a local review.");
	}
	return git(["symbolic-ref", "--short", "HEAD"]);
}

function assertBaseExists(base: string): void {
	if (!gitSucceeds(["rev-parse", "--verify", "--quiet", `${base}^{commit}`])) {
		throw new Error(`Unknown base ${base}: fetch it first, or pass the right --base.`);
	}
}

function localStatePaths(branch: string): { state: string; report: string } {
	const directory = resolve(git(["rev-parse", "--git-path", "ocr-review"]));
	const name = encodeURIComponent(branch);
	return { state: `${directory}/${name}.json`, report: `${directory}/${name}.md` };
}

// Like a merged PR's threads, a state goes away once its commits have shipped, or once the branch has nothing left to ship.
function loadLocalState(base: string): LocalState | undefined {
	assertBaseExists(base);
	const paths = localStatePaths(currentBranch());
	let state: LocalState;
	try {
		state = JSON.parse(readFileSync(paths.state, "utf8")) as LocalState;
	} catch (error) {
		if ((error as { code?: string }).code === "ENOENT") {
			return undefined;
		}
		throw error;
	}
	const hasNothingToShip = git(["rev-list", "--count", `${base}..HEAD`]) === "0";
	const hasShipped = gitSucceeds(["merge-base", "--is-ancestor", state.lastReviewedSha, base]);
	if (hasNothingToShip || hasShipped) {
		rmSync(paths.state, { force: true });
		rmSync(paths.report, { force: true });
		return undefined;
	}
	return state;
}

function writeFileAtomically(path: string, content: string): void {
	mkdirSync(dirname(path), { recursive: true });
	writeFileSync(`${path}.tmp`, content);
	renameSync(`${path}.tmp`, path);
}

function openLocalFindings(state: LocalState | undefined): LocalFinding[] {
	return (state?.findings ?? []).filter((finding) => finding.status === LocalFindingStatus.Open);
}

function findingLocation(finding: Finding): string {
	const hasRange = finding.startLine !== undefined && finding.startLine < finding.line;
	return hasRange ? `${finding.path}:${finding.startLine}-${finding.line}` : `${finding.path}:${finding.line}`;
}

// The terminal has no suggestion blocks, so a suggestion becomes a plain replacement for the cited lines.
function formatLocalFindingBody(finding: Finding): string {
	return [
		findingHeading(finding),
		finding.body,
		finding.verification === undefined ? undefined : `**How this was verified:** ${finding.verification}`,
		finding.suggestion === undefined
			? undefined
			: `**Suggested replacement for \`${findingLocation(finding)}\`:**\n\n\`\`\`\n${finding.suggestion}\n\`\`\``,
	]
		.filter((section) => section !== undefined)
		.join("\n\n");
}

function printLocalLastReviewedSha(base: string): void {
	const lastReviewedSha = loadLocalState(base)?.lastReviewedSha;
	if (lastReviewedSha !== undefined) {
		console.log(lastReviewedSha);
	}
}

function printLocalReviewState(base: string): void {
	const state = loadLocalState(base);
	const openFindings = openLocalFindings(state).map((finding) => ({
		commentId: finding.id,
		path: finding.path,
		line: finding.line,
		body: formatLocalFindingBody(finding),
		replies: finding.notes,
	}));
	console.log(JSON.stringify({ summary: state?.summary, openFindings }, null, 2));
}

function formatLocalReport(input: ReviewInput, state: LocalState, isIncremental: boolean): string {
	const openFindings = openLocalFindings(state);
	const checkedSection =
		input.checked === undefined || input.checked.length === 0
			? undefined
			: `Checked (not exhaustive):\n\n${input.checked.map((item) => `- ${item}`).join("\n")}`;
	const findingsSection =
		openFindings.length === 0
			? "No open findings."
			: `### Open findings (${openFindings.length})\n\n${openFindings
					.map((finding) => {
						const origin = finding.raisedAt === state.lastReviewedSha ? "" : " · from an earlier review";
						return `#### #${finding.id} · \`${findingLocation(finding)}\`${origin}\n\n${formatLocalFindingBody(finding)}`;
					})
					.join("\n\n---\n\n")}`;
	return [
		"## 🤖 OCR review of local commits",
		`### Confidence score: ${state.confidence}/5`,
		state.confidenceReason,
		isIncremental ? `New commits only: ${input.confidence}/5. ${input.confidenceReason}` : undefined,
		checkedSection,
		`### Summary\n\n${state.summary}`,
		findingsSection,
		`Reviewed \`${input.fromSha.slice(0, 10)}..${input.headSha.slice(0, 10)}\` on \`${state.branch}\` against \`${state.base}\` with Claude Code in OCR delegation mode.`,
	]
		.filter((section) => section !== undefined)
		.join("\n\n");
}

function postLocalReview(inputPath: string, base: string, isDryRun: boolean): void {
	const input = JSON.parse(readFileSync(inputPath, "utf8")) as ReviewInput;
	assertConfidenceIsValid("confidence", input.confidence);
	const head = git(["rev-parse", "HEAD"]);
	if (input.headSha !== head) {
		throw new Error(`HEAD is ${head} but the review covers ${input.headSha}. Review HEAD instead.`);
	}
	const state = loadLocalState(base);
	const isIncremental = input.fromSha !== git(["merge-base", base, input.headSha]);
	const verdict = pullRequestVerdict(input, isIncremental);
	assertConfidenceIsValid("prConfidence", verdict.confidence);
	const priorOpen = openLocalFindings(state);
	if (priorOpen.length > 0 && input.priorFindings === undefined) {
		throw new Error(
			`The branch has ${priorOpen.length} open local OCR finding(s): pass review-state to the reviewer and post its priorFindings.`,
		);
	}

	const closedIds = new Set(
		(input.priorFindings ?? [])
			.filter((prior) => prior.status === PriorFindingStatus.Closed)
			.map((prior) => prior.commentId),
	);
	const priorFindings = (state?.findings ?? []).map((finding) =>
		finding.status === LocalFindingStatus.Open && closedIds.has(finding.id)
			? {
					...finding,
					status: LocalFindingStatus.Closed,
					notes: [
						...finding.notes,
						{ author: "ocr-review", body: `Closed by the review of \`${input.headSha.slice(0, 10)}\`.` },
					],
				}
			: finding,
	);
	let nextId = state?.nextId ?? 1;
	const newFindings = input.findings.map(
		(finding): LocalFinding => ({
			...finding,
			id: nextId++,
			status: LocalFindingStatus.Open,
			raisedAt: input.headSha,
			notes: [],
		}),
	);
	const branch = currentBranch();
	const newState: LocalState = {
		version: 1,
		branch,
		base,
		lastReviewedSha: input.headSha,
		fromSha: input.fromSha,
		confidence: verdict.confidence,
		confidenceReason: verdict.reason,
		summary: verdict.summary,
		nextId,
		findings: [...priorFindings, ...newFindings],
	};
	const report = formatLocalReport(input, newState, isIncremental);
	if (isDryRun) {
		console.log(report);
		return;
	}
	const paths = localStatePaths(branch);
	writeFileAtomically(paths.report, `${report}\n`);
	// The state goes last: the next run treats this head as reviewed only once the report exists too.
	writeFileAtomically(paths.state, `${JSON.stringify(newState, null, "\t")}\n`);
	console.log(`${report}\n\nSaved to ${paths.report}`);
}

const USAGE = `Usage:
  node ocr-review.ts post <findings.json> [--dry-run]
  node ocr-review.ts last-reviewed-sha <pr-number>
  node ocr-review.ts review-state <pr-number>
  node ocr-review.ts post <findings.json> --local --base <ref> [--dry-run]
  node ocr-review.ts last-reviewed-sha --local --base <ref>
  node ocr-review.ts review-state --local --base <ref>`;

function parseArguments(argv: string[]): { positional: string[]; flags: Set<string>; base?: string } {
	const positional: string[] = [];
	const flags = new Set<string>();
	let base: string | undefined;
	for (let index = 0; index < argv.length; index++) {
		const argument = argv[index] ?? "";
		if (argument === "--base") {
			base = argv[++index];
			if (base === undefined || base.startsWith("--")) {
				throw new Error(`--base needs a ref.\n${USAGE}`);
			}
		} else if (argument.startsWith("--")) {
			flags.add(argument);
		} else {
			positional.push(argument);
		}
	}
	return { positional, flags, base };
}

const [command, ...rest] = process.argv.slice(2);
const { positional, flags, base } = parseArguments(rest);
const [argument] = positional;
const isDryRun = flags.has("--dry-run");
if (flags.has("--local")) {
	if (base === undefined) {
		throw new Error(`--local needs --base <ref>.\n${USAGE}`);
	}
	switch (command) {
		case "post":
			if (argument === undefined) {
				throw new Error(USAGE);
			}
			postLocalReview(argument, base, isDryRun);
			break;
		case "last-reviewed-sha":
			printLocalLastReviewedSha(base);
			break;
		case "review-state":
			printLocalReviewState(base);
			break;
		default:
			throw new Error(USAGE);
	}
} else {
	if (argument === undefined) {
		throw new Error(USAGE);
	}
	switch (command) {
		case "post":
			postReview(argument, isDryRun);
			break;
		case "last-reviewed-sha":
			printLastReviewedSha(Number(argument));
			break;
		case "review-state":
			printReviewState(Number(argument));
			break;
		default:
			throw new Error(USAGE);
	}
}
