# orchestrator

The teamlead set on top of the developer set: drive several Claude Code agents from
[herdr](https://herdr.dev) panes, one role per pane, from one orchestrating session.
Three things live here — the `orchestrator` skill, five roles, seven shell tools —
and all three ship inside the skill directory. `npx skills` installs them; a script that
comes with them links the roles and the tools to where Claude Code and your shell look.

## What is here

**The `orchestrator` skill** — the role that hands work out, watches it and accepts it. Its
protocols cover hiring, chaining, status, unblocking, evidence and handoff. It carries no
lead's standing rules of its own: it reads them from `~/.agents/standards/orchestrator.md`,
or the project's `.agents/standards/orchestrator.md`, the same slot the development skills
read code standards from. Absent both, it works to the defaults written in the protocols.

**Five roles** in `orchestrator/agents/` — `back`, `front`, `reviewer`, `tester`, `researcher` — as
native Claude Code agent definitions. Each names the skill that is its craft
(`implement-task`, `review-mr`, `clickup`) and pins its model.
`install.sh` links them into `~/.claude/agents/`, where both `recruit` and Claude Code
read them.

**Seven tools** in `orchestrator/bin/`, six of them wrappers over herdr:

| Tool | What it does | Needs |
|---|---|---|
| `recruit` | Hire an agent into its own herdr pane, optionally on a fresh git worktree | herdr |
| `roster` | Show who is hired and what each one is doing | herdr |
| `fire` | Dismiss an agent and close its pane | herdr |
| `tell` | Send text to an agent — safer than `herdr agent prompt`, which can paste without submitting and lose the message | herdr |
| `await` | Wait for an agent and tell apart the three states herdr shows identically: finished, asked a question, drifted | herdr |
| `await-mr` | The same wait, tied to a merge request appearing | herdr, glab |
| `await-validation` | Wait until an issue in validation or a merge request is assigned to you, and say which | glab, jq |

All but `await-validation` do nothing without herdr installed and its server running;
`await-validation` only reads GitLab, and the hiring it leads to goes through herdr.

## Before you install

Three things a developer does not need and a teamlead does:

- **herdr**, from https://herdr.dev. The wrappers drive its panes and the installer treats
  its absence as a stop, not a warning. Its server has to be started from a real terminal,
  never from a shell Claude Code spawned — the skill explains why in its first constraint.
- **glab**, authenticated against your GitLab (`brew install glab`, then `glab auth login`).
  Only `await-mr`, `await-validation` and the merge-request parts of the roles need it.
- **jq** (`brew install jq`), for `await-validation` only.
- **The developer set**: the ClickUp CLI from
  [claude-work-tools](https://github.com/TechTechWizard/claude-work-tools) and the six
  skills from [dev-skills](https://github.com/TechTechWizard/dev-skills). The roles call those
  skills by name, so install the developer set first, by its own READMEs.

## Install

Two commands, no clone:

```sh
npx skills add TechTechWizard/orchestrator -g -a claude-code -s orchestrator
sh ~/.claude/skills/orchestrator/install.sh
```

The first installs the skill with its roles and wrappers. The second links the wrappers into
`~/.local/bin` and the roles into `~/.claude/agents/`, then reports the prerequisites. The
links point at `~/.claude/skills/orchestrator`, which exists whether you installed for Claude
Code only or, without `-a claude-code`, for several agents at once. A missing herdr makes it
exit non-zero: the links are in place, but nothing here works yet. It refuses to run while
`~/.claude/agents` is itself a symbolic link into some repository — make it a directory
first. `BIN_DIR` and `AGENTS_DIR` move the targets; `--check` reports without touching
anything.

Installed from a clone before? Run the same two commands. `install.sh` relinks every link
that still points into the clone, leaves your own files in `~/.claude/agents` alone, and
after that the clone is no longer used.

## Check that it worked

```sh
recruit --roles          # five roles: back, front, researcher, reviewer, tester
herdr status server      # running — start it with `herdr` in a real terminal if not
clickup my-tasks         # the developer set answers
```

And in a Claude Code session, `/skills` lists `orchestrator`. The skill checks the same
things before its first hire and stops with the step to repeat if one is missing.

## Update

```sh
npx skills update
```

The links point into the installed skill, so the roles and the wrappers are new the moment
the skill is, with no second step. Only a release that adds a wrapper or a role needs
`sh ~/.claude/skills/orchestrator/install.sh` again; `--check` tells. A role that is already
running keeps the definition it started with — re-hire to apply an update.

## Your standing rules go into the slot

Capacity ceiling, model tier, a project's board route, a shared test dataset that testers
must not clobber — the skill reads these from a file named `orchestrator.md` in
`~/.agents/standards/` (yours) or `<project>/.agents/standards/` (the project's, which wins
for what it covers). Plain Markdown, any structure; write what you would otherwise repeat to
the orchestrator every session, with the reasons. Nothing breaks without it.

## Watching your validation queue

Tell the orchestrator «следи» (or "watch my queue") in a project's root, and whatever is
assigned to you for validation or review gets an agent without you asking: issues with the
status label once their merge is deployed, and open merge requests. The waiting is done by
`await-validation`, which polls GitLab every 15 minutes and costs nothing while the queue is
empty; the session has to stay open, because the watcher lives in it. GitLab only —
validation statuses in ClickUp are not supported and will not be.

Set it up once per project in `<project>/.agents/standards/orchestrator.md`: the command with
your repositories, plus who gets what (which stand a tester checks, what to do with an issue
on a document). Without that file the orchestrator asks once which repositories to watch.

```sh
await-validation \
  --project <group>/<backend-repo> \
  --project <group>/<frontend-repo> \
  --label VALIDATION --env development      # the defaults; pass them only when yours differ
```

Run it from a git checkout whose remote is on the same GitLab host — `glab` takes the host
from there. Before the first «следи», add `--dry-run` to see every item it finds and whether
it is `new`, `seen` or `not-deployed`; it writes nothing. What has been handed out is kept in
`.orchestrator/validation-seen` in the project root — add `.orchestrator/` to the checkout's
`.git/info/exclude` so it stays out of commits, and delete a line to have that item checked
again; the log is in `~/.local/state/await-validation/`. `await-validation --help` has the rest.

## Roles: where `recruit` finds them

A role is a native Claude Code agent definition, and `recruit` accepts it from either of
two places: a file in `~/.claude/agents/<role>.md` — which is where `install.sh` links
the skill's five — or an installed plugin that ships an `agents/` directory, listed
as `<plugin>:<role>`. `recruit --roles` prints every role it can see and where each one
comes from. A bare name works when exactly one definition answers to it; when two do,
`recruit` refuses and prints both spellings.

The same two spellings are valid keys in a project's `.roster`, one line per role:
`<role> <path-relative-to-project>`, with `.` meaning the project root.

## License

MIT, see [LICENSE](LICENSE).
