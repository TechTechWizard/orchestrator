# orchestrator

The teamlead set on top of the developer set: drive several Claude Code agents from
[herdr](https://herdr.dev) panes, one role per pane, from one orchestrating session.
Three things live here — the `orchestrator` skill, five roles, six wrappers over herdr —
and they are installed in two steps, because `npx skills` installs skills and nothing else.

## What is here

**The `orchestrator` skill** — the role that hands work out, watches it and accepts it. Its
protocols cover hiring, chaining, status, unblocking, evidence and handoff. It carries no
lead's standing rules of its own: it reads them from `~/.claude/standards/orchestrator.md`,
or the project's `.claude/standards/orchestrator.md`, the same slot the development skills
read code standards from. Absent both, it works to the defaults written in the protocols.

**Five roles** in `agents/` — `back`, `front`, `reviewer`, `tester`, `researcher` — as
native Claude Code agent definitions. Each names the skill that is its craft
(`implement-task`, `review-mr`, `clickup`) and pins its model.
`install.sh` links them into `~/.claude/agents/`, where both `recruit` and Claude Code
read them.

**Six wrappers** over herdr in `bin/`:

| Tool | What it does | Needs |
|---|---|---|
| `recruit` | Hire an agent into its own herdr pane, optionally on a fresh git worktree | herdr |
| `roster` | Show who is hired and what each one is doing | herdr |
| `fire` | Dismiss an agent and close its pane | herdr |
| `tell` | Send text to an agent — safer than `herdr agent prompt`, which can paste without submitting and lose the message | herdr |
| `await` | Wait for an agent and tell apart the three states herdr shows identically: finished, asked a question, drifted | herdr |
| `await-mr` | The same wait, tied to a merge request appearing | herdr, glab |

None of them does anything without herdr installed and its server running.

## Before you install

Three things a developer does not need and a teamlead does:

- **herdr**, from https://herdr.dev. The wrappers drive its panes and the installer treats
  its absence as a stop, not a warning. Its server has to be started from a real terminal,
  never from a shell Claude Code spawned — the skill explains why in its first constraint.
- **glab**, authenticated against your GitLab (`brew install glab`, then `glab auth login`).
  Only `await-mr` and the merge-request parts of the roles need it.
- **The developer set**: the ClickUp CLI from
  [claude-work-tools](https://github.com/TechTechWizard/claude-work-tools) and the six
  skills from [skills](https://github.com/TechTechWizard/skills). The roles call those
  skills by name, so install the developer set first, by its own READMEs.

## Install

Step one, the skill:

```sh
npx skills add TechTechWizard/orchestrator -g -a claude-code -s orchestrator
```

Step two, the roles and the wrappers:

```sh
git clone https://github.com/TechTechWizard/orchestrator.git ~/src/orchestrator
cd ~/src/orchestrator && ./install.sh
```

`install.sh` links `bin/*` into `~/.local/bin` and `agents/*.md` into `~/.claude/agents/`,
then reports the prerequisites. A missing herdr makes it exit non-zero: the links are in
place, but nothing here works yet. It refuses to run while `~/.claude/agents` is itself a
symbolic link into some repository — make it a directory first. `BIN_DIR` and `AGENTS_DIR`
move the targets; `./install.sh --check` reports without touching anything.

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
npx skills update                          # the skill
cd ~/src/orchestrator && git pull && ./install.sh --check   # the roles and the wrappers
```

The links point into the checkout, so `git pull` alone updates the roles and the
wrappers; `--check` catches a new file that needs a new link. A role that is already
running keeps the definition it started with — re-hire to apply an update.

## Your standing rules go into the slot

Capacity ceiling, model tier, a project's board route, a shared test dataset that testers
must not clobber — the skill reads these from a file named `orchestrator.md` in
`~/.claude/standards/` (yours) or `<project>/.claude/standards/` (the project's, which wins
for what it covers). Plain Markdown, any structure; write what you would otherwise repeat to
the orchestrator every session, with the reasons. Nothing breaks without it.

## Roles: where `recruit` finds them

A role is a native Claude Code agent definition, and `recruit` accepts it from either of
two places: a file in `~/.claude/agents/<role>.md` — which is where `install.sh` links
this repository's five — or an installed plugin that ships an `agents/` directory, listed
as `<plugin>:<role>`. `recruit --roles` prints every role it can see and where each one
comes from. A bare name works when exactly one definition answers to it; when two do,
`recruit` refuses and prints both spellings.

The same two spellings are valid keys in a project's `.roster`, one line per role:
`<role> <path-relative-to-project>`, with `.` meaning the project root.

## License

MIT, see [LICENSE](LICENSE).
