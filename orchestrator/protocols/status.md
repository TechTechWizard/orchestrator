# Status

## Two sources, both needed

```sh
roster                  # hired in herdr: name, state, kind, directory, what it is doing
claude agents --json    # every Claude session on the machine; --cwd <path>, --all
```

`roster` sorts `blocked` to the top and knows the real agent states (`idle` / `working` /
`blocked` / `done`), but it only sees herdr panes. `claude agents --json` sees every session
including the ones outside herdr — pid, cwd, sessionId, status, kind — but reports only a
coarse status and knows nothing about panes. Neither is a superset; use both.

**They join.** In `herdr agent list`, `agents[].agent_session.value` *is* the `sessionId`
from `claude agents --json`. That gives you a pane → session mapping, and by subtraction the
sessions running outside herdr that still count against capacity.

## Reading what an agent is actually doing

```sh
herdr agent read <name> --source recent --lines 80    # visible | recent | recent-unwrapped | detection
herdr agent explain <name> --json                    # why it is in the state it is in
```

**`idle` hides unsent text, and `roster` will not tell you.** `explain` will: find the
evaluated rule with `"id": "live_prompt_box"` and read its `evidence.region_preview` — that
string *is* the content of the agent's input box. Non-empty means a message is sitting there
unsent, whoever typed it (`protocols/pipeline.md`). Worth one command before you conclude an
agent is merely finished:

```sh
herdr agent explain <name> --json | python3 -c 'import json,sys
d=json.load(sys.stdin)
box=[r for r in d["evaluated_rules"] if r["id"]=="live_prompt_box"]
print(d["state"], "| box:", repr(box[0]["evidence"]["region_preview"]) if box else "?")'
```

**A long report outlives the scrollback.** `agent read` returned only the last third of a
9-minute report — the earlier sections were gone, and re-reading with a bigger `--lines`
returned the same tail. The full text is in the transcript; pull the last assistant message
out of it rather than accepting a partial report:

```sh
python3 -c 'import json,sys
last=None
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except: continue
    m=d.get("message") or {}
    if d.get("type")=="assistant":
        t="".join(c.get("text","") for c in m.get("content",[]) if isinstance(c,dict) and c.get("type")=="text")
        if t.strip(): last=t
print(last)' ~/.claude/projects/*/<sessionId>.jsonl
```

For full history without touching the pane, read its transcript:

```sh
tail -c 200000 ~/.claude/projects/<cwd-with-slashes-as-dashes>/<sessionId>.jsonl
```

These reach megabytes — `tail` them, never read one whole. This is also the cheapest way to
check whether an agent really ran the commands it claims (`protocols/handoff.md`).

## The whole session at once

`herdr api snapshot` returns agents, panes, tabs, workspaces, layouts and focus in about
9 KB. Use it when you need topology — which tab, which workspace, which pane. For "who is
working on what", `roster` is the answer.

## What to report to the lead

Report:

- anyone `blocked`, and precisely what they are waiting on
- work finished and waiting to be accepted
- an agent idle on a question you cannot answer yourself
- capacity at the ceiling, when it is blocking the next hire

Do not report: routine `working`, step-by-step progress, the fact that you polled. Lead with
`blocked`, then one line per agent. When everyone is `working` and nothing is stuck, saying
so in one line is the whole report.

## Before you decide an agent is stuck

A long tool call looks identical to nothing happening. Call `herdr agent get <name>` twice
and compare `state_change_seq` before intervening — `protocols/unblock.md`.
