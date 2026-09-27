# Handoff

## Default stance

Nothing is accepted until it is proven. "PASS", "готово" and "работает" are claims, and a
claim derived from reading code is a hypothesis — the rule and its reasoning live in
`~/.claude/agents/tester.md`, which every role is held to here. Your job at handoff is to ask
for the evidence, not to re-do the work.

Evidence was named in the task text before the work started (`protocols/hire.md`). If it was
not, that is your miss, not the agent's — ask now, and put it in the next task.

## Evidence, by kind of work

| Work | What counts |
|------|-------------|
| Backend endpoint | the actual request and its response, plus the DB row it changed |
| Frontend | screenshot path, console/network state, and which stand |
| Bug fix | the reproduction failing before, the same steps passing after |
| Review | `file:line` per finding, and the exact diff read — branch, commit or MR iid |
| Test / build run | the command and its output, not a summary of the output |
| Anything on dev | confirmation the deploy actually landed before the check ran |

## Artifacts go into the task, not only into the evidence folder

When the work has a ClickUp task, the evidence is **attached to that task**, not left in a
chat message that nobody will find next week. Put this in the task text before the work
starts, and hold the handoff to it:

| Kind of work | What gets attached |
|---|---|
| Frontend | screenshots of the working screens, or a video of the flow |
| Backend | how it was checked — the actual requests and responses |
| Research | the document itself as a file, plus a comment with the link and one line on what is inside |

`clickup attach <task_id> <file_path>` uploads a file; `clickup comment <task_id> <text>`
posts the link next to it. A 40 KB document pasted as comment text is not an artifact — it
is unreadable, and the person who has to read it will say so.

**Match the language of the task.** A project whose tasks are written in English gets
English comments. An agent reporting in Russian under an English task forces someone to
rewrite it by hand. Put the language in the task text — agents default to the language you
briefed them in.

Where the evidence physically goes — one folder per task, files named by scenario — is
`protocols/reports.md`. Name that folder in the task text before the work starts; retrofitting
a layout costs an agent-hour.

## Naming the gap is mandatory, even though the section is gone

Reports no longer exist (`protocols/reports.md`), so the gap list no longer has a section to
live in — but the obligation survives the format. Every handoff says what was *not* verified
and why, in one sentence, and you ask for it before accepting when the agent did not offer it.
A silent gap reads as PASS, and that is the most expensive thing an agent can hand you.

## Cross-check, cheaply

You have the transcript (`protocols/status.md`). `tail` it and confirm the commands the
agent's verdict rests on were actually run — this catches "I would run…" phrasing and summaries
of output nobody produced. It costs one command and it is the difference between accepting a
result and accepting a story. Cheaper still, now that the evidence is the deliverable: open the
folder. A verdict whose evidence file is not there is not a verdict.

## Returning a task that failed acceptance

A verdict nobody acts on is wasted work, and a comment nobody is assigned to is a verdict
nobody acts on. When a task comes back from acceptance with a FAIL, four things happen
together, in the task's own language:

1. **A short comment on the task** — four or five sentences: what we see, what the task's own
   scenario asked for, one line of evidence, and a direct question of whether it is intended or
   a bug. Plus the screenshot.

   **Do not paste a bug-report template into it.** A comment in the developer's own task is a
   message to a colleague, not a filed defect: title, Description, Expected Behavior and Steps
   to Reproduce belong in a separate bug report, and pasting them here buries one sentence of
   substance under a form. The mistake, when it happened, came from the instruction "take the
   ready text from the report" — so do not give that instruction.
2. **A real tag of the developer at the top of it** — a `tag` segment carrying their user id,
   not the plain string `@Name`. Plain text does not notify anyone, and looks identical in the
   report, which is how it goes unnoticed. Recipe: the README of the ClickUp CLI
   (claude-work-tools).
3. **The comment assigned to that developer.** In ClickUp a comment carries its own `assignee`
   field, separate from the task's — an unassigned comment is a remark, an assigned one is an
   action item someone has to resolve. Teams that work this way send their handoff comments
   assigned to the lead; return the favour. Setting the task assignee does **not** set this.
4. **The task reassigned to that developer.** The ball has to visibly move; a comment on a task
   still assigned to the lead reads as their problem, not the developer's.

Status is a separate decision and stays the lead's — do not move it as a side effect of the
steps above.

Scope discipline: one comment per defect, and only about the task it belongs to. A finding that
also reproduces on the sibling platform goes into *that* task's comment, not as an aside in this
one.

## Closing a task that passed

The mirror of the section above, and it needs its own steps because the mechanics are not
symmetric. The lead authorises the close — never move a status on your own initiative — and
once they have, three things happen per task, in this order.

**1. Establish the target status from the board, not from the word «закрой».** A list can
run `draft → to do → in progress → validation → complete → Closed` with both `complete` and
`Closed` in live use, and guessing picks wrong half the time. The route the team actually
walks is readable per task:

```sh
curl -s -H "Authorization: $(cat ~/.config/clickup/token)" \
  "https://api.clickup.com/api/v2/task/<id>/time_in_status" \
  | python3 -c 'import json,sys; print(" → ".join(h["status"] for h in json.load(sys.stdin)["status_history"]))'
```

If every recently closed task shows `validation → complete → Closed`, then `complete` is the
step after a passed validation and `Closed` is a later, separate move. Ask which one the lead
means when they say «закрой», or state which you picked and why. A project's slot file may
record the route once so nobody re-derives it.

**2. Reply to the implementer with a real mention.** Two or three words — the developer needs
to know the ball is off their side, not to read a report. The mention has to be a `tag`
segment carrying their user object; `@Name` as plain text notifies nobody and looks identical
afterwards. The cheapest source of that object is the author of their own handoff comment
(`GET /task/{id}/comment` → `comments[].user`). Recipe: the README of the ClickUp CLI.

```
@<developer> all good — validated on dev, closing.
```

Match the task's language.

**3. Resolve their handoff comment.** `PUT /comment/{comment_id}` with `{"resolved": true}`.

That call returns **HTTP 200 whether or not it does anything**: the checkbox exists only on a
comment that has an `assignee`, and an unassigned comment silently stays unresolved while
the call still reports success. So read it back and check the flag, never the status code:

```sh
GET /task/{id}/comment  →  comments[].resolved
```

If the comment was never assigned there is nothing to tick. Say so; do not assign it to
someone yourself to manufacture a checkbox.

**A comment beyond the mention is usually padding.** The status change already says validation
passed. Write one only when it carries a fact the task does not — for instance a task whose
written scenarios were overtaken by later work, where a future reader would otherwise
conclude it was closed with a defect.

Batch these one task per command. A loop over seven updates reads as bulk mutation and gets
stopped by the safety classifier, and a half-applied loop is worse than seven visible calls.

## An agent's question is yours before it is the lead's

`await` returning `ASKING` is not a cue to forward the question. Read it and split it in three:

- **What the project already answers** — a rule in `CLAUDE.md`, a standard, an ADR, the code
  itself, the task text. Answer it yourself and say in the report that you did, with the source.
  Most «ЖДУ РЕШЕНИЯ» stops land here.
- **What you can establish** — a fact that a command, a fixture or a diff settles. Establish it,
  or hire someone to establish it. A question is not a substitute for a check.
- **What is genuinely the lead's product choice** — a number nobody has agreed, a scope cut, a
  tradeoff between two behaviours users will feel. This one is named out loud in the handover,
  one sentence, with your recommendation attached. It never blocks the rest of the wave:
  everything that does not depend on the answer is finished before you hand anything over.

Naming a choice is not interviewing them. What is banned is the round of questions you could
have answered from the rules, the code or a command — see `SKILL.md`.

## Closing the loop

1. Accept, or send it back — `protocols/unblock.md` for the re-explain vs re-hire call.
2. Next stage, if there is one — `protocols/pipeline.md`.
3. `fire <name>` when the hire is finished. The worktree survives on purpose; remove it with
   `git -C <repo> worktree remove <checkout-path>` after the branch is merged — `recruit` makes
   the checkout with git, so there is no herdr worktree workspace to remove (`protocols/hire.md`).
4. Hand over to the lead: **verdict per item → what is broken in one sentence → the gap, if
   any → what happens next.** Lead with the verdict, keep it to a few lines, and be ready to
   answer from the evidence files — they will ask, and that is the designed channel.

## Do not fix it yourself

If the result is wrong, an agent fixes it — the same one or a fresh one. The moment you edit
the code, you are the author of the work you were supposed to be accepting, and nobody is
left to review it.
