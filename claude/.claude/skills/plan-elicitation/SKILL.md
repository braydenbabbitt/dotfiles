---
name: plan-elicitation
description: Use before writing any plan for multi-step work when the request leaves design decisions unsettled, and whenever the user asks to "flesh out", "spec out", or "make decisions about" a feature or change. Elicits decisions, missing context, and spec details from the user through dependency-ordered question rounds where every option carries a concrete example, its trade-offs, and the best practice it follows; records answers in the plan document as they arrive; and closes with a consolidated summary for sign-off before the plan proper is written.
version: 1.0.0
---

# Plan elicitation

Read and follow `~/.config/agent-workflows/plan-elicitation/PROTOCOL.md` in
full. That document is the canonical protocol and is shared across agents; this
skill only makes it discoverable from Claude Code.

In brief, the protocol requires:

1. Investigate the codebase thoroughly first. Never ask a question the
   repository can answer.
2. Probe four dimensions for open decisions: scope and behavior, UX and edge
   states, data/interfaces/compatibility, quality and non-functional. Mark any
   that do not apply as not applicable.
3. Ask in dependency-ordered rounds using `AskUserQuestion`, at most about four
   questions per round, foundations before details. Every option carries a
   concrete example of what it looks like in practice, its trade-offs, and the
   convention or best practice it follows. Recommend only when a clear best
   practice or existing convention points one way.
4. Create or open the plan document before the first round and keep its
   Open questions, Decisions (`[user]` / `[agent]` tagged, with rejected
   alternatives and why), and Assumptions sections current after every round.
5. Close with one consolidated summary and wait for sign-off. "Go" at any point
   means resolve the rest as tagged agent-chosen decisions and proceed.

When invoked explicitly as `/plan-elicitation`, run the full protocol even if
no ambiguity was detected, and treat any existing draft plan as the input.
