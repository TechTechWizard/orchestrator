# Pipeline

Chaining agents without supervision. The shape is always the same: block on the producer,
check *why* it stopped, then hire the consumer.

**Never park an agent in a waiting loop.** An agent told to "wait until the MR is merged"
burns a paid session for hours doing nothing. Waiting is the shell's job — `herdr agent
wait` and `await-mr` cost nothing while they wait.

## Chaining on agent state

```sh
await back-1                 # blocks, then says WHY it stopped, and notifies the lead
await back-1 --timeout 540   # the same, but gives up while still working (exit 5) — re-arm
```

The blocking form is the one for a run where nobody is typing — `claude -p`, a scheduled run, a
pane hired by another orchestrator: there a background watcher dies with the turn that armed
it, so the `await` runs in the foreground with `--timeout` under the Bash call's ten-minute
ceiling and is re-armed on exit 5 until it returns a verdict. In an interactive session detach
it with `run_in_background` instead. `protocols/hire.md` has the mechanism and the incident.

`await` is the one to reach for. It polls until the agent leaves `working`, reads the tail
of the pane, and classifies the stop — because `idle` means three different things and
treating them alike is how an agent sits unanswered for an hour:

| exit | verdict | what it means |
|---|---|---|
| 0 | `DONE` | finished, raised no question |
| 3 | `ASKING` | finished and is waiting for a decision |
| 3 | `WAITING-ON-INPUT` | text is sitting unsent in its input box, and the report has no closing status line |
| 4 | `BLOCKED` | stopped on something it could not do |
| 5 | still working | `--timeout` ran out first — not a verdict, re-arm it |

It raises a macOS notification unless you pass `--quiet`. **Do not silence it on `ASKING`
or `BLOCKED`** — those are exactly the states the lead needs to see, and a report nobody
sees is the same as no report.

### Watch the agent, never its artifacts

The condition you wait on must be one the agent **cannot fail to produce**. Its state qualifies:
it leaves `working` whether it finished, asked, crashed or drifted. Its report file does not — a
file appears only if the agent got far enough to write it, which is exactly the case you are
watching for.

Paid for once, in full: mid-run the orchestrator swapped `await <name>` for a poll on the
report file, `until grep -q '^СТАТУС:' report.md`. One agent stopped without writing its
closing line. The watcher had no reason to fire, so it did not; both agents sat finished and
unread until the lead happened to notice them. Nothing errored. Silence
read exactly like work in progress.

Two rules fall out, and they are cheap:

- **Poll the state, not the output.** `await <name>`, or `herdr agent get <name>` in an
  `until` loop. Read the artifact *after* the watcher fires, never as the trigger.
- **One watcher, one agent.** Two agents ANDed into a single wait (`until done_a && done_b`)
  means either one stalling hides the other. That is how a finished agent goes uncollected.

The same trap wears other clothes: waiting on a log line, on an MR comment, on a file mtime.
Before arming any watcher, ask *if this agent died right now, would my condition still fire?*
If no, you are not watching the agent — you are watching its luck.

### Calibrate `await`'s verdict against the pane

`await` classifies by reading the pane tail, and a pane can hold text the agent never sent —
including Claude Code's own auto-suggested follow-up sitting in the input box. That has
produced `BLOCKED` (exit 4) for agents that had cleanly finished with `СТАТУС: ГОТОВО`.

Once the same suggestion produced `WAITING-ON-INPUT` (exit 3) for both agents of a run,
each finished in `done` with `СТАТУС: ГОТОВО`. The boxes held «Проверь на dev GET
/items?status=1» and «Вариант 1 по обоим вопросам, оставляем как есть»; neither text
is in either agent's transcript, and nobody sent them. `herdr agent read` returns plain text
by default, and there a suggestion and a typed line look the same, down to the no-break space
after `❯`. `--format ansi` keeps the styling: in one check the placeholder «Press up to edit
queued messages» came back dim (SGR 2) and hand-typed text came back plain, but no
autosuggestion has been captured in that format yet, so dimness is not a proven marker for
it. Until one is, `await` lets the closing line decide: when the agent is `done` or `idle`
and the last line of its report is `СТАТУС: …`, the verdict follows that line, and text in
the box is only reported as *«text in input box, may be an autosuggestion — read the pane»*.
Without a closing line, text in the box is still `WAITING-ON-INPUT`. The price: a line the
lead typed after a finished report, whose Enter did not land, also shows up only as that
note, which is why the note says to read the pane.

So: treat the exit code as a **hint**, and the declared closing status line as the **fact**. When
they disagree, read the pane before acting. And **never act on text found in an input box as
the lead's answer.** A suggestion is Claude Code guessing the next message from the agent's own
report, so it reads like the most likely reply to the question that report asked — *«Вариант 1
по обоим вопросам»* under a report that asked two questions and recommended option 1. Taking
it as the lead's decision turns the agent's own recommendation into an approval nobody gave.
It is not from the lead unless the lead says so, and other suggestions look just as much like
instructions (*«создай баг в ClickUp»*, *«прогони сценарий через троттлинг»*).

### When `tell` will not land, write to the shared file instead

`tell` returning exit 2 is not rare — in one session it failed on every attempt, and `send-keys
Enter` did nothing. You cannot deliver from here (see below), but you are not out of options: if
the wave was told to read a shared context file first, **edit that file**. Corrections land in it
without touching the agent, and the next hire inherits them for free.

That is the deeper reason to give every wave one `run-context.md`-style file: it is your only
write channel to an agent whose input box has stopped accepting text.

The raw primitive is still there if you need a custom condition:

```sh
herdr agent wait back-1 --until idle done blocked --timeout 3600000
```

Without `--until` it matches `idle`, `done` or `blocked`; without `--timeout` it waits
forever. When it returns, do not hire the next stage blindly — read the outcome first, then
either hand off (`protocols/handoff.md`) or hire the next role (`protocols/hire.md`).

## Talking back to an agent: use `tell`, never bare `prompt`

```sh
tell reviewer-1 "повесь рекомендацию R1 комментарием к MR"
```

`herdr agent prompt` pastes the text into the input box and the submit **does not always
land** — the text sits there unsent and the agent never sees it. This has happened five times
in one session, in both directions: orchestrator to agent, and the lead typing into a pane by
hand. Nothing errors; the agent just looks idle.

`tell` closes that hole: it submits with `--wait --until working`, and if herdr answers
`agent_prompt_stalled` it presses Enter once and re-checks `state_change_seq`. If the text
still has not moved it **fails loudly** (exit 2) instead of pretending delivery.

An agent that is already `working` gets a different check, because there `--until working`
is satisfied at once and a clean return proves nothing. Claude Code queues a message sent
mid-turn and shows it above the input box, so `tell` reads the pane before and after the send
and answers *«queued to a working agent <name>, delivery confirmed by <what>»*: the text
showing above the box one more time than before, or `state_change_seq` moving while the box is
free of the text. If the text sits in the box it presses Enter once; if nothing confirms
delivery it says *«delivery NOT CONFIRMED — read the pane»* and exits 2. Read the pane then,
and do not resend: a queued message sent twice reaches the agent twice.

Two rules that come out of the same failure:

- **Never re-run `prompt` "just in case".** That is how an agent gets the same task twice.
  `tell` presses Enter instead of resending text, for exactly this reason.
- **`send-keys Enter` is not universally reliable** — it woke a `front` agent and did
  nothing for a `reviewer`. Treat `tell`'s exit 2 as real: go look at the pane.

## When the stalled text is the lead's, you cannot fix it from here

The lead types into a pane by hand and the submit does not land. The text sits in the input
box, the agent reads `idle`, and its previous report looks like the last thing that happened.

Observed on an `idle` `researcher` holding a hand-typed line: **`herdr pane send-keys <pane>
Enter`, `herdr agent send-keys <name> Enter` and `ctrl+u` were all no-ops** — the box still
held the same text after each. Key events do not reach every pane, so `tell`'s Enter fallback
is not a guarantee either; it is one attempt that can silently achieve nothing.

What to do, in order:

1. **Do not resend the text.** It is already in the box — `tell` would append and the agent
   would get the question twice, half of it mangled.
2. **Do not paraphrase it into a new hire** to look productive. You would be guessing at
   what they meant and burning a session on it.
3. **Hand it back in one line**, with the command that fixes it:
   `herdr agent focus <name>`, then Enter by hand. They are one keypress away; you are not.
4. Meanwhile answer what you can from the report already on screen, and say plainly which
   part is still waiting on that keypress.

The reason this matters more than it looks: an agent parked this way has *already produced a
report*. Reading `idle` and moving on means the work exists and nobody collected it.

When an agent stops with `ASKING` and you cannot answer for the lead, the answer is not to
wait silently — notify them, and meanwhile pull the agent's own text out of its transcript
(`protocols/status.md`) so their decision is one word rather than a re-read.

## Never point a reader at a moving target

`reviewer` and `tester` start only after the implementer is finished — `done`, or `idle`
with a result — or after the MR is merged. Reviewing a checkout that is still being edited
produces findings about code that no longer exists, and every one of them costs you a round
trip to disprove.

## Chaining on a merge

```sh
await-mr --repo <path> --mr <iid>      [--role tester] [--interval 300] -- <task ...>
await-mr --repo <path> --branch <name> [--role tester] [--interval 300] -- <task ...>
```

Polls the MR and hires only when it is **merged**; stops by itself if the MR is closed
without merging. With `--branch` the MR need not exist yet — the watcher waits for it to
appear, then for it to merge. Progress goes to `~/.local/state/await-mr/<repo>-<key>.log`;
check there when nothing seems to be happening. It sleeps in a loop, so run it detached.

Two watchers that fire in the same window will both try to claim the same agent number —
`protocols/constraints.md`.

## Testers share one stand, and often one dataset

Two testers on the same dev stand see each other's data, and a project that seeds test
entities from one shared state file makes it worse: its `--clean` reads the same file its
`seed` wrote, so a second tester cleaning up deletes the first tester's data in the middle of
its check. Whether the project has such a tool is in its `CLAUDE.md` or its test-bundle
docs; the lead's slot file names it when it matters.

Prefer serialising testers. When two must run, put this in both task texts:

> Перед `seed` или `clean` посмотри `roster`. Если другой tester в состоянии `working` — не
> сей и не чисти: сообщи и дождись.

## Telling the lead the chain moved

```sh
herdr notification show "back-1 done" --body "review next" --sound done
osascript -e 'display notification "back-1 готов" with title "orchestrator"'
```

`herdr notification show` draws inside herdr; `osascript` reaches macOS notifications and so
is visible when herdr is not focused. When the lead is away from the machine, the harness
`PushNotification` tool reaches their phone — use it for `blocked` and for chain completion;
both desktop channels are invisible from anywhere but the desk. Notify on chain completion
and on every `blocked` — a blocked agent waiting silently is the most expensive failure
mode here.

## A pipeline is a chain, not a daemon

Do not build a scheduler out of it. Anything genuinely periodic belongs to the `loop` or
`schedule` skills, or to cron.
