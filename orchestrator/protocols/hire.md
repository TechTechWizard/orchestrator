# Hire

## Before you hire

1. `protocols/constraints.md` — server up, capacity left, one writer per checkout.
2. `roster` — is someone already on this repo, and is a hire even needed?
3. Is there a role for this work? `recruit --roles`. If not, `protocols/roles.md` — but do
   not invent a role to avoid thinking about the task.
4. `grep -L '^model:' ~/.claude/agents/*.md` — it must print nothing. A role that does not
   pin its model runs on whatever tier the hiring session happens to use, which is how three
   top-tier sessions once burned an account limit mid-review (`protocols/constraints.md`, §7).
   Fix the file before the hire; an agent cannot be moved to another model after it started.

## Pick the role

The role is a mandate, not a technology. `front` and `back` write code; `reviewer` cannot
(no `Write`/`Edit`); `tester` deliberately keeps every tool because testing needs a
browser, kubectl and curl, and is held by its mandate instead. The live registry is
`recruit --roles`; the mandates are in `~/.claude/agents/<role>.md`.

## Where it works

```sh
recruit <role> [task ...]                                    # role's default checkout
recruit <role> --worktree <branch> [task ...]                # fresh git worktree on <branch>
recruit <role> --worktree <branch> --repo <dir> [task ...]   # ... of a named repository
```

`recruit` walks up from cwd for the nearest `.roster` and treats that directory as the
project root, so **run it from inside the project**. Lines are `<role> <dir-relative-to-
that-file>`, `.` meaning the root. Example — a project root holding a web and an API
checkout side by side:

```
front     web
back      api
reviewer  .
tester    .
```

A `.roster` row maps a directory and nothing more — it does not register a role. A row for
a role that has no `~/.claude/agents/<role>.md` makes `recruit <role>` die before it touches
herdr.

Use `--worktree` when: a second writer needs the same repo; the branch must not disturb the
main checkout; the work is long-lived and you want it isolated. The branch is created for
the hire.

Every hire lands in a tab of the project workspace, `--worktree` included. `recruit` makes
the checkout itself with plain `git worktree add` under `~/.herdr/worktrees/<repo>/<branch>`
and then opens an ordinary tab there. `herdr worktree create` is deliberately not used: in
herdr a worktree *is* a workspace, so that command always opens a new one and groups it with
the repository's own — behaviour identical on 0.7.5 and on 0.9.0, and the reason worktree
hires used to appear outside the project in the sidebar.

`--worktree` has to know which repository to branch from, and a `.roster` row names a
directory that is not always one: a project root that holds three repositories is not a
checkout itself, and `recruit reviewer --worktree` there dies with `not_git_worktree`.
`recruit` resolves the repository in this order — an explicit `--repo <dir>`, then the
role's own directory when it is a checkout, then the single repository directly under the
project root. With several candidates it refuses to guess and prints them, so on such a
project the normal form is `recruit reviewer --worktree review-<id> --repo <checkout>`.

`fire` does **not** delete the worktree — remove it deliberately with
`git -C <repo> worktree remove <checkout-path>` once the branch is merged.

## Anatomy of a good task

This is where hires succeed or fail. Six blocks, in this order. Do not restate the role
file — the agent has already read it; a second copy only drifts from the first.

1. **Frame** — one line on what this hire owns here and what it does not touch.
2. **Goal** — the observable end state, not the steps to it. "Endpoint returns X for case
   Y", not "open the controller and add a method".
3. **Order of work** — where to start reading and what to do first. Without it the agent
   explores, and exploration is where drift starts.
4. **Anti-drift clause** — mandatory. Real case: a `front` agent found a broken
   `settings.local.json`, went off to fix it, and lost the task. This wording held:

   > Сломанный инструмент или конфиг — одна строка что именно сломано, и продолжай задачу
   > доступными средствами; не начинай починку инфраструктуры отдельным проектом; не меняй
   > ничего в `.claude/`.

5. **What is NOT a defect** — mandatory for `reviewer` and `tester`. Name the known,
   deliberate rough edges up front. Example: until the paired backend MR is deployed the
   frontend renders a dash instead of a number — a decision, not a bug. Skip this and a
   junk finding is close to guaranteed.
6. **Evidence required** — what proof must come back. See `protocols/handoff.md`; state it
   before the work starts, not when you are refusing the result.

   In the same block, require an **«Открытые вопросы»** section in the report: every question
   the agent could not settle itself, written as the question in plain words, why the answer
   matters, the options with their cost, and its own recommendation. The lead answers
   reports, not chat prompts (`protocols/reports.md`), so a question that exists only in the
   agent's closing status line dies with the pane. Demand the recommendation explicitly — a
   question list with no recommendation pushes the thinking back onto the lead, which is the
   thing this rule exists to prevent.

7. **A closing status line** — mandatory, and cheap. Require the report to end with exactly
   one of these:

   ```
   СТАТУС: ГОТОВО
   СТАТУС: ЖДУ РЕШЕНИЯ — <вопрос в одну строку>
   СТАТУС: БЛОКЕР — <что именно не смог>
   ```

   `await` classifies a stop by reading the pane, and it guesses well, but a declared line
   beats a guess: it tells you in one grep whether the agent finished or is waiting on you,
   without re-reading a 200-line report. Ask for the question **in that line**, not only in
   the body — then answering costs the lead one word.

## Do not build waiting into the task

A task that says "принеси текст и дождись «да»" makes the agent stop and wait **by
design**. That is correct for creating tasks in ClickUp and for anything outward-facing, and
it is how the roles are written — but it means every such hire ends in `ASKING`, and someone
has to notice. Two consequences for the task text:

- Say plainly **what to do while waiting**: finish the rest, clean up, write the report. An
  agent parked on a question with cleanup unfinished leaves the stand dirty for the next one.
- If the lead is away, say so in the task: *«Ответов сейчас не будет — вопросов не задавай;
  упрёшься — пиши `⏭` с причиной и иди дальше»*. Otherwise the agent waits for an answer
  that cannot come for hours.

Add the `glab`-inside-the-repo rule (`protocols/constraints.md`) to any task involving an
MR, and the shared-dev-data rule (`protocols/pipeline.md`) to any task for a `tester`.
A layout/UI task gets the exact design node URL in the task text — when the roles carry a
Figma toolchain, a hire without the link wastes its first turn hunting for it.

## Delivering it

`recruit <role> "<task>"` — the task is one argument; multi-line is fine.

The first prompt after `agent start` can be swallowed: `interactive_ready` arrives before
the TUI has drawn its input box. `recruit` watches `state_change_seq` and re-sends once if
the agent did not move — and a re-send will one day deliver the task twice. If you prompt
by hand, pause first, then confirm with `herdr agent get <name>`.

A directory Claude Code has never opened puts its trust dialog in front of the TUI, and the
first hire there used to die with «stayed busy» while herdr already listed the agent as
`blocked`. `recruit` now reads the pane, answers «Yes, I trust this folder» — the lead chose
the directory, so the decision is theirs and already made — prints `trust dialog answered`
and continues with delivery. `protocols/unblock.md` says what the dialog is and what to do when
`recruit` reports it could not answer.

## The hire is not finished until a watcher is armed

```sh
recruit researcher "<task>"
await researcher-1              # ← same breath, every single time; detach it via Claude
                                #   Code's background Bash (run_in_background), not a bare &
```

`recruit` returns the moment the task is delivered. Nothing after that reports back on its
own: an agent that finishes, asks a question, or stalls with unsent text in its input box
just sits there looking `idle`, and you find out when the lead tells you. **A hire with no
armed `await` is an unfinished hire** — treat the two commands as one action, and run the
`await` detached so it survives your turn.

How the detach works, and where it does not. In an interactive session, Claude Code's
background Bash (`run_in_background: true`) is the right detach: the session lives on between
turns, and when the background command exits the harness re-invokes the session with its
output, so the watcher's verdict lands in front of you even if you never went back to check —
a `&`-detached `await` can only notify the desktop and hope someone is looking.

None of that holds when nobody is typing. A session started with `claude -p`, a pane hired by
another orchestrator, a run started from a script or a schedule — each of those is a process
that exits the moment your turn ends, and every background watcher dies with it. Paid for
once: a `-p` session armed `await researcher-1` in the background, wrote «жду, пока
researcher закончит», and ended its turn; the process exited with code 0, the watcher's output
file read `[killed]`, the agent finished seven minutes later, and nobody accepted it. So the
rule that survives both kinds of session is: **never end a turn while a hire is unaccepted.**
In an interactive session the background `await` is what keeps that promise. In a
non-interactive one, run the `await` in the foreground and carry on to the acceptance in the
same turn: the Bash tool stops a call at ten minutes, so give the call its maximum `timeout`
(600000 ms), run `await <name> --timeout 540`, and re-arm it on exit 5 (still working) until
it returns a verdict. `protocols/pipeline.md` shows the blocking form.

Which kind of session you are in is something you know before the first hire, not something
you detect with a command: the lead's own words («меня не будет до утра», «ответов не будет»),
a prompt that arrived as one block carrying the whole plan, no TUI in front of anyone. When in
doubt, the foreground `await` is the safe default — in an interactive session it costs one
blocked turn, while a background `await` in a headless one costs the whole run.

Two ways this rule gets broken, both paid for:

- **Hiring after a `fire`.** Watchers were armed for the first wave, the wave finished, it
  was fired — and the next hire went out with nothing listening. Arming is per hire, not
  per session. Re-check with `roster` against your live watchers whenever you fire.
- **"I will just check on it later."** You will not: the next tool result buries the intent,
  and in a headless run there is no later at all — the turn you end is the last one.
  Arm it, or accept that the lead is your monitoring.

The invariant to hold: **every agent in `roster` that you have not yet accepted has exactly
one watcher armed** — and that watcher polls the agent's **state**, never a file it is expected
to write. No more (duplicate notifications), no fewer (silent work), and never one watcher
covering two agents. A report file is not a heartbeat: an agent that dies before writing it never
trips the condition, and you learn it from the lead. Incident and reasoning: `protocols/pipeline.md`.

One sharp edge: `await` on an agent that is *already* out of `working` returns immediately and
tells you nothing you did not know. So arm it **after** delivering work, not as a retroactive
patch — and if you catch yourself arming one late, read the pane instead; the answer is
already sitting there.

"Same breath" means the next tool call, before any planning of what comes after. The gap
between delivery and the watcher is the window in which a short task finishes unobserved:
once three minutes of thinking went by between `tell researcher-1` and
`await researcher-1`, harmless only because that task took eleven. `recruit` prints the
exact `await` line after a successful delivery for this reason — copy it into the next call
rather than composing it later. It prints and does not run it, because the watcher must
belong to your session to report back to you.

To reach an agent that is already hired:

```sh
herdr agent prompt <name> "<text>"                        # fire and forget
herdr agent prompt <name> "<text>" --wait --until idle     # block until it settles
```

Caveat straight from `--help`: `--wait` does not track turns. If the agent was already
working, the completion of *that* turn can satisfy the wait. Confirm with
`herdr agent get`.

## If you ever hire by hand

Don't — call `recruit`. It exists because of two traps: a pane reports `agent_pane_busy`
for seconds after `tab create` even when its foreground process is a clean zsh, and a
readiness probe returns instantly so retrying on it burns every attempt inside one second.
The fix is a retry loop with a **real** pause; `recruit` blocks ~1.2s by waiting for output
that never arrives. Read `bin/recruit` in this repository before writing anything of your own.
