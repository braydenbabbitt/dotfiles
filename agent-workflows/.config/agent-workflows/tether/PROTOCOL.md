# Tether (crash-recoverable work)

Tether makes any multi-step coding task resumable after an interruption —
a crashed process, a dropped connection, a closed terminal, a new session, or a
context reset. It is **agent-agnostic**: it relies only on a plain Markdown plan
document and greppable code comments, so any coding agent (or a human) can pick
up the work.

The core idea: **the work lives on disk, not in chat.** A task progresses through
four explicit phases. A plan document captures the thinking; code comments mark
the concrete change sites. Both are plain files in the repo, so nothing important
is held only in volatile chat context.

Every task gets a distinct `<name>` that namespaces both its plan document and its
code markers. That namespacing is also what makes tether **safe under parallel
sessions**: multiple agents can work in the same checkout at once, each on its own
`<name>`, without adopting or clobbering each other's in-progress work. See
"Recovery" for the rule that keeps a session from grabbing another session's plan.

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

   **Tests get one marker per test case.** When the work involves tests, do not
   write a single lumped "add tests here" marker. Write a **separate**
   `TODO(plan:<name>)` comment for **each individual test case**, and each comment
   must describe (a) what that case exercises and (b) the expected behavior it
   verifies. This makes the intended coverage explicit and reviewable before any
   test code exists, and in Phase 3 each case is implemented and its marker
   removed one at a time, exactly like any other site. For example:

   ```
   // TODO(plan:appointment-reminders): test — creating a reminder with a past
   //   date is rejected; expect a 422 and no row written.
   // TODO(plan:appointment-reminders): test — a reminder fires exactly once even
   //   if the scheduler tick runs twice; expect a single send, idempotency key reused.
   ```

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
explicit confirmation. When the user confirms, advance the `[-]` box in the plan
document's checklist (mark the finished phase `[x]`, the new one `[-]`) **before**
starting the new phase's work.

**Phase 1 → Phase 2 (special case).** The plan document is itself the artifact
under review at this gate, so its approval can double as the gate:

- If the user **manually approved** writing the plan document (they saw it and
  confirmed the edit), treat Phase 1 as complete and proceed to Phase 2.
- If the document was **auto-approved** — written without a manual approval
  prompt (e.g. `acceptEdits`/`dontAsk` mode, or permissions that allow the write
  silently) — the user has not actually reviewed it. **Stop and ask** for explicit
  confirmation before starting Phase 2.

**Phase 3 → Phase 4 (special case).** The Phase 3 edits are the artifact under
review at this gate, so their approval can double as the gate:

- If the user **manually approved every edit** made in Phase 3 (each was seen and
  confirmed), treat the implementation as reviewed and proceed to Phase 4 cleanup
  automatically — no separate confirmation needed.
- If **any** Phase 3 edit was **auto-approved** — applied without a manual approval
  prompt (e.g. `acceptEdits`/`dontAsk` mode, or permissions that allow the edit
  silently) — the user has not actually reviewed that work. **Stop and ask** for
  explicit confirmation before starting Phase 4.

## The plan document

Location: `.plans/<name>.md`, where `<name>` is a short, stable, kebab-case name
for the task (mirroring the branch name is a good default). This same `<name>` is
used in the code markers, linking the two.

The document MUST begin with a small status block so any agent can recover the
phase at a glance:

```markdown
# <name>

**Goal:** one sentence stating the end state.

- [x] 1. Plan
- [-] 2. Identify code changes
- [ ] 3. Implement
- [ ] 4. Cleanup

## Context & decisions

<prose: the problem, the approach chosen, alternatives weighed, constraints,
open questions. No code snippets. No per-site edit checklist.>
```

Checklist box states: `[x]` complete, `[-]` in progress, `[ ]` not started. The
`[-]` box is the single source of truth for where the task stands — at most one
box is `[-]` at a time. Keep it accurate at all times. If **no** box is `[-]`
(e.g. a phase gate was just passed but the next phase hasn't started), the
**first** incomplete `[ ]` box is the next phase to start.

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

Tether is **followed at the start of every session, without exception.** A
`SessionStart` hook runs `tether-status` automatically and injects its output (the
active plans plus a directive) into context, so recovery is not something you opt
into — it runs every session by construction. Act on that output before doing
anything else.

**Parallel sessions share this repo.** Multiple agent sessions can run against the
same checkout at once (worktrees are optional, not required), so the `.plans/`
directory and the `TODO(plan:...)` markers you see may belong to **other sessions
still actively working on them**. A plan being in-progress does **not** mean it is
*yours* to resume. Never adopt, edit, implement, or clean up an in-progress plan
just because it exists — doing so collides with the session that owns it.

**The disambiguator is relevance to the user's actual request, not session
identity.** Agents have no stable session id to key on, so ownership is decided by
what the user has asked you to do this session:

1. **Discover** in-progress work: read the `tether-status` output (or run
   `ls .plans/` and `grep -rn "TODO(plan:"` yourself). Each `<name>.md`'s `[-]`
   checklist box reports its phase; a plan still in phase 1 has **no** markers yet,
   so always check `.plans/` too, not just the markers.

2. **Match** each in-progress plan against the user's request for this session.
   Resume a plan **only if** one of these holds:
   - the user **explicitly** refers to it (by name, or "keep going / resume / finish
     what you were doing"), **or**
   - the job the user is asking for **is the same work** that plan describes — its
     goal or subject matter clearly matches the request.

   If **no** in-progress plan matches, **leave every existing plan and its markers
   untouched** and treat the request as new work — start a fresh plan at Phase 1
   under a new `<name>` (see "When to use this protocol"). Do not resume, advance,
   or clean up someone else's plan as a side effect. When in doubt about whether a
   plan is yours to touch, **ask the user** rather than adopting it.

3. **Resume** the matched plan (if any) according to its `[-]` phase (or, if no box
   is `[-]`, the first `[ ]` box — the next phase to start):
   - Phase 1: continue refining the plan document.
   - Phase 2: continue dropping `TODO(plan:<name>)` markers at remaining sites.
   - Phase 3: resume from any remaining `TODO(plan:<name>)` marker.
   - Phase 4: verify, then delete the plan document.

   Re-read the surrounding code before continuing — the document says *what* and
   *why*, the markers say *where*. Trust the code if they disagree.

Because every plan and every marker is namespaced by a distinct `<name>`, parallel
sessions working on **different** `<name>`s never step on each other: grep, cleanup,
and completion checks below are all scoped to a single `<name>`.

**Keep recovery quiet.** The discover/match reasoning above is bookkeeping, not
something the user needs narrated. Do it privately — in your reasoning, not the
visible reply — and let the *outcome* decide what, if anything, you say:

- **No match, or nothing in progress** (the common case): say **nothing** about
  tether at all. Do not report that you ran `tether-status`, that other plans
  exist, or that you decided to start fresh. Just proceed with the work (opening a
  new plan silently if the task warrants one).
- **Resuming a matched plan:** one short line naming the plan and phase you're
  resuming, then continue — no recap of the elimination process.
- **A phase gate, or a genuine ambiguity you must ask about:** surface only that.

In short: tether should be visible to the user only when it changes what happens
next, never as a running commentary on session startup.

## Completion & hygiene

- The task is done only when **both** the plan document is deleted **and** no
  `TODO(plan:<name>)` markers remain, with tests/build passing.
- Scope completion checks to **your** `<name>`, never to all plans — a parallel
  session's markers or plan file are not yours to clean up or block on. Before
  committing or opening a PR, confirm your own work is fully landed:
  `grep -rn "TODO(plan:<name>)"` (your exact `<name>`) returns nothing and
  `.plans/<name>.md` is gone. Treat a leftover marker or plan file **for your
  `<name>`** as an unfinished task, not noise.
- Other `<name>`s left behind by concurrent sessions are expected and fine; leave
  them in place. Do **not** run a bare `grep -rn "TODO(plan:"` and treat another
  session's markers as blockers for your change.

## When to use this protocol

Use it at the **start** of any task that spans more than a single edit or that you
couldn't redo from memory in one pass. Skip the ceremony for trivial one-line
changes.

**Single-file changes — ask first.** If the whole change is contained to a single
file, the protocol is likely overkill. Before setting up a plan document, **ask
the user whether they'd like to skip the protocol altogether** for this change. If
they say yes, proceed directly without any tether scaffolding; if they say no,
follow the phases as normal.
