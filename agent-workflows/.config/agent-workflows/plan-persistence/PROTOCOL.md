# Plan Persistence Protocol (crash-recoverable work)

This protocol makes any multi-step coding task resumable after an interruption —
a crashed process, a dropped connection, a closed terminal, a new session, or a
context reset. It is **agent-agnostic**: it relies only on a plain Markdown plan
document and greppable code comments, so any coding agent (or a human) can pick
up the work.

The core idea: **the work lives on disk, not in chat.** A task progresses through
four explicit phases. A plan document captures the thinking; code comments mark
the concrete change sites. Both are plain files in the repo, so nothing important
is held only in volatile chat context.

## The four phases

Every non-trivial task moves through these phases **in order**. The current phase
is recorded in the plan document (see below).

1. **Plan** — Produce a plan document (`.plans/<name>.md`) capturing all context
   and decision-making behind the changes: the goal, the reasoning, the
   trade-offs considered, and the approach chosen. The plan document contains
   **no code snippets and no checklist of edits** — it is prose that explains
   *what* and *why*, not *where* or *how* line-by-line.

2. **Identify code changes** — Walk the codebase and drop a `TODO(plan:<name>)`
   comment at **every site** where a change is needed. Each comment states what
   that site needs. When the plan calls for a brand-new file, create the file
   containing **only** the TODO comment — nothing else. No code is written in
   this phase; you are only marking the work.

3. **Implement** — Resolve the `TODO(plan:<name>)` comments **one at a time**.
   For each site: make the change, then **remove that TODO comment in the same
   edit**. The set of remaining markers is the live to-do list; it shrinks to
   zero as the work completes.

4. **Cleanup** — Once no `TODO(plan:<name>)` markers remain and the work is
   verified (tests/build pass), delete the plan document. Confirm the repo is
   clean of both the markers and the plan file.

## Phase gates (user confirmation)

**At the end of each phase, stop and ask the user whether to proceed to the next
phase.** Do not roll from Plan into Identify, or Identify into Implement, without
explicit confirmation. When the user confirms, update the `Current phase` field
in the plan document **before** starting the new phase's work.

## The plan document

Location: `.plans/<name>.md`, where `<name>` is a short, stable, kebab-case name
for the task (mirroring the branch name is a good default). This same `<name>` is
used in the code markers, linking the two.

The document MUST begin with a small status block so any agent can recover the
phase at a glance:

```markdown
# <name>

**Goal:** one sentence stating the end state.
**Current phase:** 2 — Identify code changes

- [x] 1. Plan
- [x] 2. Identify code changes   <-- in progress
- [ ] 3. Implement
- [ ] 4. Cleanup

## Context & decisions

<prose: the problem, the approach chosen, alternatives weighed, constraints,
open questions. No code snippets. No per-site edit checklist.>
```

Keep `Current phase` accurate at all times — it is the single source of truth for
where the task stands. The phase checklist above it is a human-readable mirror of
the same fact.

## The code marker (phases 2–3)

Tag every change site with the `TODO(plan:<name>)` marker, using the comment
syntax of the file's language (`//`, `#`, `<!-- -->`, etc.):

```
// TODO(plan:appointment-reminders): wire create/update mutation to the scheduling API
```

`TODO(plan:` is the literal string the tooling greps for — keep it exact. For a
new file, the file's entire initial contents are a single such comment:

```
// TODO(plan:appointment-reminders): new ReminderForm component — see .plans/appointment-reminders.md
```

These markers are transient work-in-flight state, distinct from ordinary
`TODO:`/`FIXME:` backlog notes. They must not survive into a merged change.

## Recovery (start of every session — mandatory)

This protocol is **followed at the start of every session, without exception.** A
`SessionStart` hook runs `plan-status` automatically and injects its output (the
active plans plus a directive) into context, so recovery is not something you opt
into — it runs every session by construction. Act on that output before doing
anything else:

1. List active plans: `ls .plans/` — each `<name>.md` reports its `Current phase`.
   (You can also run `plan-status` or `grep -rn "TODO(plan:"` to find the code
   markers directly, but note a plan still in phase 1 has **no** markers yet —
   the plan document is the only trace, so always check `.plans/` too.)
2. Read the plan document and resume according to its `Current phase`:
   - Phase 1: continue refining the plan document.
   - Phase 2: continue dropping `TODO(plan:<name>)` markers at remaining sites.
   - Phase 3: resume from any remaining `TODO(plan:<name>)` marker.
   - Phase 4: verify, then delete the plan document.
3. Re-read the surrounding code before continuing — the document says *what* and
   *why*, the markers say *where*. Trust the code if they disagree.

## Completion & hygiene

- The task is done only when **both** the plan document is deleted **and** no
  `TODO(plan:<name>)` markers remain, with tests/build passing.
- Before committing or opening a PR, confirm nothing is left behind:
  `grep -rn "TODO(plan:"` returns nothing and `.plans/<name>.md` is gone. Treat a
  leftover marker or plan file as an unfinished task, not noise.

## When to use this protocol

Use it at the **start** of any task that spans more than a single edit or that you
couldn't redo from memory in one pass. Skip the ceremony for trivial one-line
changes.
