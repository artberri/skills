# Setting up execute-plan

Guidance for `adapt-skill` when it installs or refreshes the `execute-plan` template. It is not copied into the project.

## What to look for

- **An installed `create-plan`:** if `.claude/skills/create-plan/` exists, reuse its plans folder and ticket rules, so the two skills agree.
- **An installed `ship`:** if `.claude/skills/ship/` exists, take the branching (pull requests or the main branch, branch naming, ticket rule) and the commit convention from it rather than asking again.
- **Tests:** the test skills the project has, the command to run one test file, and where each kind of test lives.
- **Checks before a commit:** formatter, linter, type check and their scoped forms (changed files, one package), from `package.json` scripts, the Makefile or the task runner, and the git hooks that already run some of them.
- **Special procedures:** skills or docs for database migrations, code generation (after changing events, schemas or API specs) and batch scripts.

## Questions, in this order

**A. Plans folder.** Reuse `create-plan`'s. If it isn't installed, recommend the existing folder, or `.agents/plans/`.

**B. Branching and commits.** Reuse `ship`'s conventions if it's installed. Otherwise ask whether work goes through feature branches or straight to the main branch, propose the branch naming and ticket rule you found, and the commit convention (Conventional Commits unless the project uses another).

**C. Tests.** Propose how tests are written and run.

**D. Checks before each commit.** Propose the scoped commands, or say which a git hook already runs.

**E. Special procedures.** Propose the ones you found, if any.
