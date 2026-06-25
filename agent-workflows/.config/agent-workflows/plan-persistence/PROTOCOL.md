# Plan Persistence Protocol (crash-recoverable work)

This protocol makes any multi-step coding task resumable after an interruption —
a crashed process, a dropped connection, a closed terminal, a new session, or a
context reset. It is **agent-agnostic**: it relies only on plain comments in the
code and one shell script, so any coding agent (or a human) can pick up the work.

The core idea: **the source tree is the source of truth for in-progress work.**
Every active plan and its step-by-step state live as greppable comments in the
files being changed, so nothing important is held only in volatile chat context.

## The marker

Tag every plan with a stable, kebab-case name and write it as a checklist using
the `TODO(plan:<name>)` marker:

```
// TODO(plan:appointment-reminders): goal — wire the reminders UI to the scheduling API
// TODO(plan:appointment-reminders): [x] add /reminders route
// TODO(plan:appointment-reminders): [x] build ReminderForm component
// TODO(plan:appointment-reminders): [ ] wire create/update mutation   <-- next
// TODO(plan:appointment-reminders): [ ] add e2e coverage
```

Use the comment syntax of the file's language (`//`, `#`, `<!-- -->`, etc.).
`TODO(plan:` is the literal string the tooling greps for — keep it exact. Tooling
(the `plan-status` script today, an editor plugin later) parses each line as:

```
TODO(plan:<name>): [<space|x>] <text>   [<-- pointer]
```

so keep that shape: one step per line, `[ ]` or `[x]`, optional trailing `<-- …`.

## When to create a plan block

Create one at the **start** of any task that spans more than a single edit or
that you couldn't redo from memory in one pass. Skip it for trivial one-line
changes.

- **Name**: short, kebab-case, stable for the life of the task (reuse it across
  files and sessions). If a branch exists, mirroring the branch name is a good default.
- **Location**: put the master checklist at the top of the *primary* file you're
  changing. For a multi-file plan, keep ONE master checklist in an anchor file and,
  if helpful, leave a one-line `// TODO(plan:<name>): see <anchor-file> for plan`
  breadcrumb in the other files. Don't duplicate the full checklist everywhere.
- **First line is the goal**: a single sentence stating the end state, so a fresh
  agent understands intent without the original prompt.

## Update discipline

- Flip `[ ]` → `[x]` in the **same edit** that completes the step. The checklist
  must never be ahead of or behind the actual code.
- Mark the current step with a trailing `<-- next` (or `<-- in progress`) pointer
  so recovery starts in the right place instantly.
- If the plan changes, edit the checklist — add/reorder/remove steps. The block is
  living scaffolding, not a historical record.

## Recovery (start of every session)

1. Find all active plans: run `plan-status` (installed at `~/.local/bin/plan-status`)
   or `grep -rn "TODO(plan:"` from the repo root.
2. For each plan, resume from the first `[ ]` step (the `<-- next` pointer).
3. Re-read the surrounding code before continuing — the checklist says *what*'s
   left, the code says *where things actually stand*. Trust the code if they disagree.

## Completion & hygiene

- Delete the **entire** plan block only when the plan is fully done **and verified**
  (tests/build pass). An unchecked box left behind means the work isn't finished.
- These markers are scaffolding — they should not survive into a merged change.
  Before committing/opening a PR, confirm no `TODO(plan:...)` markers remain
  (`plan-status` reports them). Treat a leftover marker as an unfinished task, not noise.
- This is distinct from ordinary `TODO:`/`FIXME:` comments — those are permanent
  backlog notes; `TODO(plan:...)` is transient, work-in-flight state.
