# What agents leave behind

**No reports are written for code review or for task validation.** What gets cancelled is
the prose — `report.md`, `evidence.md`, a published page per wave. The evidence is not
cancelled: it is the thing the agent was hired for.

## The split everything rests on

**Evidence is the output of a command.** An API response, an SQL dump, a screenshot, a diff
patch, a `file:line` list. A machine produced it; a human does not retell it. Evidence lives
as files in the task's folder.

**The verdict is a conversation.** The lead asks, the orchestrator answers from the evidence.
If the evidence holds no answer, that is the signal the check was incomplete — and it surfaces
now, not a week later.

Why this way and not the other: a lead who received a wave page and a chat summary still
asked «ты уверен, что там есть проблема?». The report did not contain the answer; it was
found in twenty minutes from a saved API response, the state of the dev database and the
code. So the evidence layer was doing the work, and the prose layer only stood between them.

## The task folder

```
.orchestrator/reports/
  <task-id>-<short-slug>/
    00-mr-discussions.json      glab api response
    02-full-diff.patch          git diff
    04-archived-no-edit-button.png    screenshot of a scenario
    05-list-request.txt         the saved request
    findings.md                 ONLY when there are findings — see below
  bugs/<slug>.md                a bug-report draft, when one is needed
  archive/                      finished waves
```

The rules are the old ones, and none of them is about prose:

- **One task, one folder.** Evidence sits next to the task it belongs to.
- **Numbered by scenario, named by content**: `08-guest-no-delete-button.png`. The number
  ties the file to a line of the verdict; the words say what is inside without opening it.
- **Saved API responses and database selections are evidence too**, same folder, same rule.
- **History is not deleted, it moves** into `archive/`.

## `findings.md` — the only file with text in it, and it is not a report

Written only when there is something to fix. One line per finding, nothing else:

```
FAIL  the action button is chosen by type, not by the destination's state
      3 buttons of 6 lead to a 422 → use-item-actions.tsx:79
      evidence: 11-activated-action-item-42-422.txt, 02b-list-response.json
```

Forbidden in it: a retelling of the diff, a retelling of the task, "what was done well",
checklists with "not applicable", introductions, conclusions. If a line does not name what
breaks and where that is visible, the line should not exist.

Threshold: **no findings, no file.** An empty `findings.md` saying "all good" is a one-line
wall of text, and it is not needed either.

## Handing over to the lead — spoken and short

A verdict per item and one phrase on what is broken. A link to the resource on first mention.
Then they ask — the orchestrator answers from the evidence, without re-asking the agent and
without hiring a new one.

```
<Project> · 3 tasks

mobile <task-id> — accept, no defects
web <task-id> — 3 buttons of 6 lead to a dead end
web <task-id> — 2 types without photos, fixable only together with the backend

Ask about any of them — the evidence is in the folders.
```

What was dropped from the old format and does not come back: the published wave page, the
verdict table across every scenario, the "Open questions" section, the "Not verified and why"
section, "Positives", the summary across a review batch, the header of facts.

Three of those were not decoration, so they need a replacement rather than plain deletion:

- **"Not verified"** moves into the spoken answer as one phrase, and only when it changes
  the decision: «экспорт проверить нечем — бэкенд ещё не написан». Silence about
  a gap still reads as PASS and is still the worst thing you can hand over.
- **"Open questions"** — the same: a genuine product choice is named out loud in one phrase,
  with a recommendation. Whatever the project's rules, the standards, an ADR or the code
  already decide, the orchestrator decides itself and does not raise.
- **What was changed on the shared stand** — a mandatory line of the spoken answer whenever
  something was: passwords, data created and deleted, notifications marked read.

## The orchestrator answers itself, it does not re-ask the agent

Since no prose is written, the only one holding the whole picture is the orchestrator. Hence
an obligation that did not exist before: **read the evidence before handing over, not after
the lead's first question.** Knowing what lies in the folder and what each file proves is
enough; retelling them into your own context is not needed.

When the lead asks «ты уверен?» — that is not a cue to defend the agent's conclusion. It is a
cue to re-check it against the evidence and the code, and to say plainly if the agent rounded
itself up or if the scale turned out different.

## A finding not published to the merge request dies with the round

This rule is about GitLab, not about reports, and it stands unchanged: **a finding the lead
did not post to the merge request is a finding the team is not using, and the next round
ignores it.**

- The next round does not re-raise unpublished findings.
- A verdict cannot rest on an unpublished finding: the author could not physically act on it.
- What the author saw is read from the threads, not from memory:
  `glab api projects/<id>/merge_requests/<iid>/discussions`.

Draft MR comments are collected in a separate file in the task folder and published only on
the lead's word — one line of confirmation, once.

## A wave's decisions still become ADRs

An approach chosen from alternatives, a scope cut, "we do X and not Y" — that is a `proposed`
ADR in the project's `docs/adr/` on its `0000-template.md`, not a line in the spoken answer.
Facts and observations are not decisions: they stay evidence. Only the lead moves an ADR to
`accepted`.
