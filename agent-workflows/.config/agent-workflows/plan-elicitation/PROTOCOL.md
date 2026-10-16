# Plan elicitation (decide with the user before planning)

Plan elicitation is the step **between** a request and a plan. Its job is to
surface every decision, missing piece of context, and under-specified detail
**before** any plan is written, and to get each one settled by the user rather
than quietly assumed by the agent. It is **agent-agnostic**: it relies only on a
plan document on disk and a question-and-answer loop in chat, so any coding
agent (or a human) can run it.

The core idea: **a plan built on silent assumptions is a plan for the wrong
thing.** The cheapest moment to discover a wrong assumption is before the plan
exists. So the agent reads the code, finds what the request and the code do not
settle, and asks, with concrete examples and honest trade-offs, until nothing is
open. Every answer is written to the plan document as it arrives, so the "why"
behind the plan is on disk before the "what".

This protocol does not care how the plan document is structured or where it
lives, only that one exists and holds the sections described under "The
ledger". It composes with whatever planning workflow is already in use.

## When it applies

Run elicitation whenever a plan for multi-step work is about to be written
**and** the agent, after investigation, finds at least one **open decision**: a
point where two reasonable choices would lead to materially different work and
neither the request, the codebase, nor the project's documentation settles it.

Choices that **do** have an obvious answer (an existing convention, a project
standard, the only reversible option) are not open decisions. They become
**assumptions**: still written down, still shown to the user, but not asked.

If investigation finds **no** open decision, elicitation does not disappear. The
agent lists every assumption it is making and waits for the user to confirm
before planning (see "Closure"). The user, not the agent, is the judge of what
was obvious.

When the user invokes the protocol explicitly (by name, or by asking to "flesh
out" / "spec out" something), run it in full regardless of whether the agent
detects ambiguity. An existing draft plan is a valid input: elicit against it.

## Investigate first

**Never ask a question the repository can answer.** Before the first question,
read the area the work touches: the entry points, the existing patterns for the
same kind of thing, shared components and hooks that would be reused, project
documentation, and any parity or spec documents. The goal is twofold:

- Questions become concrete. Every option can cite what already exists ("the
  thread filter persists in URL params; the status filter is single-select").
- Questions become fewer. Anything the code already decides is an assumption,
  not a question.

A question that is later retracted because the code answered it is a sign that
investigation was too shallow. Investigate until the remaining questions are
genuinely the user's to answer.

## The four dimensions

Every elicitation probes **each** of these dimensions. A dimension that does
not apply to the task is marked **not applicable** in the plan document, never
silently skipped. The dimensions are a checklist for finding open decisions,
not a template for questions: only open decisions are asked.

1. **Scope and behavior.** The goal in one sentence; what is explicitly in and
   out of scope; the primary flows; acceptance criteria. Unstated scope
   boundaries are the single largest source of rework.

2. **UX and edge states.** Empty, loading, error, permission-denied,
   concurrent-edit, limits, offline, and the transitions between them. Edge
   states decided after the happy path get bolted on inconsistently.

3. **Data, interfaces, and compatibility.** Data models, persistence,
   API and prop contracts, migrations, backwards compatibility, feature flags
   and rollout. Interface decisions are the hardest to reverse.

4. **Quality and non-functional.** Testing strategy per layer, performance,
   security and privacy, accessibility, internationalization, observability
   and analytics. Deciding the test strategy up front fixes the expected
   behavior before the code exists.

## Asking

### Rounds

Questions go out in **rounds**. A round holds the open questions that are
**independent of each other**, at most about four. A question whose options
depend on an earlier answer waits for the round after that answer arrives.
Rounds continue until no open decision remains.

Order rounds from foundations to details: scope and data-shape decisions first,
because they change which later questions even exist; edge states and quality
decisions last.

Use a structured question tool when the agent has one. Otherwise, number the
questions in prose with the same content. Either way, the user must be able to
answer with something other than the listed options.

### Every question

Each question carries, for **every** option:

- **A concrete example of what that option looks like in practice.** The
  medium matches the decision: a sample call or signature for an API, an
  interaction walkthrough or a sketch for UI, a sample record for data, a step
  sequence for a process. "Shareable URL" is a label; `?assignee=u_123` and
  "reload keeps the filter" is an example.
- **Its trade-offs**, stated as honestly for the recommended option as for the
  rest. A trade-off names what is gained and what is given up, not just
  adjectives.
- **The best practice or existing convention it aligns with or departs from**,
  when there is one.

### Recommendations

Recommend an option **only when a clear best practice or an existing
convention points one way**, and say which. Put the recommended option first
and label it. When the choice is genuinely a matter of preference, present the
options neutrally and say so; do not manufacture a recommendation.

### Deferral

When the user answers "you decide" or "whatever is best", the agent decides
(best practice, then existing convention, then the most reversible option) and
records it in the plan document tagged as **agent-chosen** with the rationale.
Agent-chosen decisions stay visibly distinct from user decisions so the user can
audit, at any later point, which decisions they never actually made.

## The ledger

**Create or open the plan document before the first round**, and keep it
current after every round. A crash, a dropped connection, or a context reset
mid-elicitation must lose nothing: a resuming agent reads the document and
continues from the open questions.

The document holds three sections, in whatever position the surrounding plan
format allows:

- **Open questions.** Each pending decision, with the round it is planned for.
  Items leave this list as they are answered.
- **Decisions.** Each settled decision, tagged `[user]` or `[agent]`, with the
  alternatives that were rejected and why. The "why" is the point: it is what a
  future reader needs to safely revisit the decision.
- **Assumptions.** Every default the agent chose without asking, with the
  convention or reason behind it. The user confirms these at closure.

Dimensions marked not applicable are recorded alongside, with a short reason.

The ledger contains **no code and no edit checklist**. It is the reasoning
record; the plan's concrete steps come after elicitation, not during.

## Closure

When no open question remains, present **one consolidated summary**: every
decision with its tag, the rejected alternatives in brief, every assumption,
and the dimensions marked not applicable. Then wait for the user to approve or
to reopen any item. Only after approval does planning proper begin.

The summary exists so the user sees the whole picture once, and can catch an
interaction between two decisions that each looked fine in isolation.

**The "go" escape hatch.** At any point the user may say "go", "proceed", or
"you decide the rest". The agent then resolves every remaining open question
itself (as under "Deferral"), lists each one as an agent-chosen decision in the
summary, and proceeds without a further sign-off. The remaining items are still
written to the plan document, still tagged, still auditable.

## Keeping it proportionate

Elicitation should feel like a careful colleague, not a questionnaire.

- Ask only what the repository and the request cannot answer.
- Never ask a question whose options are not materially different in outcome.
- Fold trivial choices into assumptions; the user will reopen any they care
  about.
- A fully specified request yields a short assumptions list and one
  confirmation, not a round of questions.
- The elicitation rounds are the user's time. Thorough investigation up front
  is how the agent respects it.
