# Constraints

Environment invariants. They bind every other protocol — read once per session, before the
first hire. All of them were paid for in practice.

## 0. The second half of the installation has to be there

The skill arrives with `npx skills`; the wrappers and the roles arrive with `install.sh`
from the same repository, and nothing makes a person run both. Before the first hire:

```sh
command -v recruit                      # the wrappers are on the PATH
ls ~/.claude/agents/*.md                # the roles are where recruit and Claude Code read them
```

Either one missing means the second step of the repository's README was skipped. Stop
and say which step, with its two commands — do not hire by hand around it
(`protocols/hire.md` says why), and do not write a role of your own to fill the gap.

## 1. The herdr server must start from a clean shell — so you can never start it

Every shell Claude Code spawns carries `CLAUDE_CODE_CHILD_SESSION=1`. A herdr server
started in such a shell passes that variable to every pane it launches, and those agents'
transcripts are never written to disk. **Your `Bash` is always such a shell** — check it
and you will see the variable set. So starting the server is not your call to make:

```sh
herdr status server                       # is one already up?
```

If it is not running, ask the lead to start it in a real terminal. In their prompt, `! herdr`
runs it in their session, which is clean.

After a hire, this is how you confirm the server was clean — the transcript exists:

```sh
ls ~/.claude/projects/*/<sessionId>.jsonl   # sessionId: see protocols/status.md
```

Look the transcript up by `sessionId`, never by path. The project directory is named after
the cwd the pane **started** in, not the directory the agent later `cd`-ed into, so a
missing `-Users-…-<some-worktree>` folder proves nothing about the server: a hire without
`--worktree` starts in the project root and files everything there. That misreading has
cost a full round once — a clean server was declared broken because the folder was looked
up by the worktree's name.

`herdr tab create --env KEY=VALUE` can set a variable per tab, which looks like a way to
neutralise the inherited one; it has not been tested as a fix. The server-level rule is
the reliable one.

## 2. One writing agent per checkout

Two agents holding `Write`/`Edit` in the same directory race on files and on
`.git/index.lock`. A second writer of any role goes into a worktree — see
`protocols/hire.md`. `reviewer` has no `Write`/`Edit` at all and can share a checkout, but
that is not permission to point it at a moving one (`protocols/pipeline.md`).

## 3. Capacity: a ceiling on concurrent sessions

Default ceiling: **6–9 concurrent sessions** on the paid tier; the lead's slot file
overrides it. Count what is already running before you add — `roster` for herdr panes,
`claude agents --json` for everything else on the machine (`protocols/status.md`). Over the
ceiling, serialise with `herdr agent wait` or `await-mr` instead of hiring in parallel.

The ceiling protects against a real thing: an account's session limit hit in the middle of
a review, which kills the review and everything queued behind it. §7 explains why a
`reviewer` hire counts as two sessions rather than one. If a hire dies on a session limit,
say so and drop back — do not keep adding.

## 4. `glab` resolves the host from the repo's remote

The global config answers `gitlab.com` — including when you run it inside a repository that
lives on a self-hosted GitLab, so `glab config get host` is never the answer to "which
host". The effective host comes from the repo's `origin`.

Consequence: every `glab` call runs with cwd inside the target repo. Say this in the task
text whenever an MR is involved, or the agent will run `glab` from the wrong place, get an
empty result, and conclude the MR does not exist.

### `glab api` takes arrays and nested objects only as real JSON via `--input`

`-f` builds a flat form body, and the API discards anything that is not a scalar key. Two
ways this was paid for:

- `-f 'assignee_ids[]=<id>'` on `PUT projects/<id>/merge_requests/<iid>` → **HTTP 400**,
  *"assignee_id, assignee_ids, … are missing, at least one parameter must be provided"*.
  GitLab does not see the bracket syntax at all, so the request reads as empty.
- `-f 'position[position_type]=text'` on `POST …/discussions` → **HTTP 201 and a wrong
  result**: the flat keys are ignored silently and you get a general MR comment instead of
  an inline one. This one is worse — it looks like it worked.

The form that works, for both:

```sh
echo '{"assignee_ids":[<id>]}' | glab api -X PUT \
  -H 'Content-Type: application/json' projects/<id>/merge_requests/<iid> --input -
```

Rule of thumb: the moment a parameter is an array or an object, drop `-f` entirely and pipe
JSON through `--input -`. Then **verify the effect, not the exit code** — read the assignees
back, or check the note came back as `"type": "DiffNote"` and not `null`.

## 5. Check native before building anything

Before you write a wrapper, run `--help`. Do not quote flags from memory. Already native:

```
claude --agent <role>            session starts in the role, restrictions from frontmatter
claude --agents '<json>'         inline agent, no file
claude agents --json             all Claude sessions on the machine; --cwd <path>, --all
claude --bg                      session as a background agent
claude -w, --worktree [name]     git worktree for the session
claude ultrareview [target]      cloud multi-agent review of branch/PR; --json, --timeout
herdr agent prompt <n> <text> --wait --until <state> --timeout <ms>
herdr agent wait <n> --until idle|working|done|blocked|unknown --timeout <ms>
herdr notification show <title> --body <text> --sound done|request
```

History, so it is not rebuilt: the first version of roles was homegrown — a roles directory,
flag files with an allow-list, `--append-system-prompt-file`. All of it is gone, replaced by
`--agent` plus `tools:` in frontmatter. Do not reinvent it.

## 6. Agent names race

Two `recruit` runs in the same window both compute `tester-1`. `recruit` recomputes the
number on every `agent start` attempt and renames the pane if someone took it — see
`bin/recruit` in this repository. Any automation you write must do the same or it will collide.

## 7. Every role pins its model, and a hire can be two sessions

A role file without `model:` in its frontmatter does not get a default — it gets **the model of
the session that hired it**. That once put two `reviewer` hires on the most expensive tier at
double the price, each carrying a review context of 100–160k tokens. Nothing announced the
tier: `recruit` does not print it, `roster` does not show it, and the only visible trace was
the footer inside the pane. The roles shipped in `agents/` pin their model for that reason.

```sh
grep -L '^model:' ~/.claude/agents/*.md              # must return nothing before the first hire
herdr agent read <name> --source recent --lines 5    # the pane footer names the live model
```

Two consequences, the second of them the expensive half:

- **Run that `grep` before the first hire of a session.** A missing `model:` is invisible at
  hire time and cannot be repaired afterwards — an agent read its definition when it started,
  so the fix is a re-hire (`protocols/roles.md`).
- **A hire can spawn its own sessions, and they inherit its model.** The `review-mr` skill
  tells a reviewer to run the built-in `code-review` skill, which runs as a background agent —
  so one `reviewer` hire is up to two sessions on the same tier, and the third such session is
  what hits an account's session limit mid-review. Count `reviewer` and `back` as two against
  the ceiling in §3.

Choosing the tier is the lead's decision, not a saving you make quietly. When the budget is
tight, economise by hiring fewer agents, not by dropping the tariff — a cheaper reviewer that
misses the defect costs more than the review. Pinning is not that decision; it only stops the
tariff from being picked by accident. The lead's slot file names the tier if it differs from
the roles' default.
