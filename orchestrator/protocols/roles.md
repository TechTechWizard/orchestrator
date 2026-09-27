# Roles

## The registry is a command, not a list

```sh
recruit --roles          # every ~/.claude/agents/*.md with its description
```

The roles shipped in this repository's `agents/` are `front`, `back`, `reviewer`, `tester`,
`researcher`. What each one is for lives in its own `~/.claude/agents/<role>.md` and nowhere
else — no second copy is kept here, because a second copy drifts from the first.

## One file, two ways to use it

- **In a pane** — `claude --agent <role>`, which is what `recruit` runs. Own session, own
  transcript, survives your context. Use it for long, interactive or open-ended work.
- **As a subagent** — the same file through the `Agent` tool inside any session (older
  Claude Code called this tool `Task`). Result comes back into your context. Use it when the
  work fits a turn and you want the answer, not a pane. A finished subagent is not gone:
  `SendMessage` with its id continues it with context intact — prefer that to a fresh spawn
  when the follow-up targets work it already did.

Tool restrictions from the frontmatter apply identically either way.

## Adding a role

1. **File** — `~/.claude/agents/<name>.md`. Frontmatter owns everything:
   - `name` — must match the filename.
   - `description` — the discovery key. A router picks the role by this text, so write what
     it is for and include the trigger words; `tester` shows the pattern with its Russian
     triggers.
   - `tools` — the restriction. **Omitting it grants every tool**, which is what `tester`
     does deliberately; `reviewer` omits `Write` and `Edit` so it *cannot* touch product
     code. A restriction is stronger than an instruction — prefer it where it fits the role.
   - optional `model`, `skills`, `color`.
2. **Body** — the mandate: what it owns, what is not its business, boundaries where it must
   stop and ask, definition of done, reporting language. Point at the skills by name
   (`implement-task`, `clickup`) and at the standards by the lookup they describe. Do not
   paste checklists into a role file. Copy the *shape* of an existing role, not its text.
3. **`.roster`** — add `<name> <dir-relative-to-the-project-root>` (`.` = root) in
   `<project>/.roster`. This only tells `recruit` where the role works; it does not register
   anything (`protocols/hire.md`).
4. **Verify — all four, this is the step that gets skipped:**

   ```sh
   recruit --roles | grep <name>                 # the file is discoverable
   claude --agent <name> -p "Кто ты и что тебе запрещено?"
   claude --agent <name> -p "Print the exact list of tool names you have."
   ```

   A misspelled `--agent` makes `claude` print the available agents, which is also how you
   check spelling. For the restriction, do not accept a hedge: if the answer does not name
   the tools, tell it to attempt the forbidden tool and report the error it gets. An
   unenforced `tools:` list is worse than none — it buys false confidence.
5. **Model** — `model:` is **mandatory**, and it is the one field whose absence costs money
   silently. A role file without it does not fall back to a default; it inherits the model of
   whatever session hired it (`protocols/constraints.md`, §7). Write the tier out — the one
   the shipped roles use, unless the lead's slot file names another — and never `inherit`.

## Changing a role

A running agent read its definition when it started; editing the file does not reach it.
Re-hire to apply a change, and expect anything in flight to still be following the old
mandate.
