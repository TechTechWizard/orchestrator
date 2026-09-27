# Unblock

`agent_status` says an agent stopped. It never says why. Diagnose before you act — read the
pane (`protocols/status.md`), then pick from below.

## `blocked` — waiting on a permission decision

The decision is **the lead's**. Not yours.

Read the pane, report what exactly is being asked with enough context that they can answer in
one word, and wait. Do not approve on their behalf, and do not route around it by performing
the action yourself — you would be doing the work you are supposed to be handing out.

If a role keeps blocking on the same legitimate permission, the fix is its `tools:` or the
project settings, not another click — `protocols/roles.md`.

One `blocked` is not a permission and is not the lead's: **the workspace trust dialog.** A
directory Claude Code has never opened on this machine gets «Is this a project you created or
one you trust? — No, exit / Yes, I trust this folder» before the TUI draws, and herdr reports
the pane as `blocked` while it stands. That question is whether the folder's own settings and
hooks may be loaded at all, and the lead answered it when they put the directory in `.roster`
or ran `recruit` inside it. So `recruit` answers it itself and goes on to deliver the task;
you only see it when `recruit` could not move the cursor onto «Yes» — then its error names the
two `herdr pane send-keys` commands that answer it and the `tell` that delivers the task
afterwards. A trust dialog in a pane you did not hire through `recruit` is the same decision,
already made by whoever chose the directory; answer it the same way. There is no flag that
pre-accepts it for an interactive session (`claude --help`: the dialog is skipped only under
`-p` or a non-TTY stdout), which is why the wrapper reads the pane instead.

## `idle` — ambiguous, always read the output

Three different situations wear this state:

- **Finished** → `protocols/handoff.md`.
- **Asked a question** → answer it with `tell` if it is inside the task's frame; escalate to
  the lead if it is a product decision.
- **Drifted and stopped** → below.

## `done` → `protocols/handoff.md`

## Lost the task

Symptoms: working on something nobody asked for, "fixing" tooling or config, rewriting
adjacent code, or a report about a problem unrelated to the goal.

**Re-explain** — cheap, keeps the context — when the goal is intact and it wandered one
step. Prompt it naming the drift, restating the goal, and repeating the anti-drift clause
from `protocols/hire.md`.

**`fire` and re-hire** — expensive, clean — when its context is now full of the wrong
problem, when it has already made changes you do not want, or when you re-explained once
and it drifted again. Before firing, look at `git status` / `git diff` in its cwd and decide
what happens to those changes: `fire` closes a pane, it reverts nothing and it leaves any
worktree in place.

```sh
fire <name>          # asks for confirmation if the agent is still `working`
```

That confirmation reads stdin, so a non-interactive call on a working agent will hang. Wait
for it to settle, or answer `y` yourself.

Then re-hire with the anti-drift clause sharpened for the exact trap it fell into. A
re-hire with the same task text usually reproduces the same drift.

## Not detected / `unknown`

```sh
herdr agent explain <name> --json
herdr agent read <name> --source visible
```

The pane may have lost its agent — crash, or the process exited. If what you see is a shell
prompt, there is nothing to unblock: re-hire.

## Looks stuck, is not

Compare `state_change_seq` across two `herdr agent get <name>` calls. If it is moving, the
agent is inside a long tool call — leave it alone. Interrupting a working agent costs its
whole turn.
