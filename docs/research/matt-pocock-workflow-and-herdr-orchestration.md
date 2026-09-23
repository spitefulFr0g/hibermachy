# Matt Pocock workflow and Herdr orchestration

Research date: 2026-08-30  
Targets: `mattpocock/skills` `main`; Herdr `0.8.2` installed locally and
`herdrdev/herdr` `master`

## Question

What do the first-party definitions of `wayfinder`, `to-spec`, `to-tickets`,
and `implement` require, and how can a project-root Codex skill safely inspect
that workflow, offer the next work, dispatch it to Herdr agents, and monitor
those agents?

## Short answer

Matt Pocock's workflow is not four interchangeable ticket queues. It is a
pipeline with two genuine frontiers:

```text
wayfinder decision frontier -> to-spec -> to-tickets -> implementation frontier
```

- Wayfinder owns a map plus decision tickets. Its frontier is the open,
  unblocked, unclaimed child tickets. A Wayfinder session normally resolves one
  decision ticket, while independent research tickets may run in parallel.
- `to-spec` synthesizes already-settled context into one spec and publishes it.
- `to-tickets` converts the agreed spec or plan into dependency-linked,
  single-context vertical slices. Its frontier is any ticket whose blockers are
  done.
- `implement` consumes one ticket per fresh session, drives TDD and verification,
  reviews the result, and commits on the current branch.

Herdr provides the necessary control surface: create panes or worktree
workspaces, start named agents, prompt them, wait for lifecycle changes, inspect
`blocked` agents, and read their output. It does not itself decide ticket
eligibility, resolve tracker claims, answer human-in-the-loop prompts, or make
concurrent edits to one checkout safe. Those remain orchestrator responsibilities.

## Sourced workflow facts

### Repository prerequisites and tracker authority

The engineering skills expect per-repository configuration created by
`setup-matt-pocock-skills`: an issue-tracker description, triage-label vocabulary,
and domain-document layout. The setup source writes those conventions under
`docs/agents/` and teaches the other skills to read them. GitHub, GitLab, local
Markdown, and a described custom tracker are supported shapes. ([setup skill](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md))

For the local Markdown tracker, a feature has `.scratch/<feature-slug>/spec.md`
and one implementation issue per file under
`.scratch/<feature-slug>/issues/`; a Wayfinder effort instead has `map.md` and
child issue files with `Type:`, `Status:`, and `Blocked by:` fields. The local
frontier is the first numbered open, unblocked, unclaimed file. ([official local-tracker template](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/issue-tracker-local.md))

For GitHub, the Wayfinder map is labelled `wayfinder:map`; its children are
sub-issues where available; blocking uses native issue dependencies where
available; and a claim is assignment to the driving developer. The documented
frontier query filters the map's open children to those with no open blocker and
no assignee. ([official GitHub-tracker template](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/issue-tracker-github.md))

### Wayfinder: a decision frontier, not a build backlog

Wayfinder is for work too large for one agent session when the route to the
destination is still unclear. The map is the canonical, low-resolution index;
the detailed answer to each decision lives on its ticket. Its live tickets are
questions sized to one agent session and typed as `research`, `prototype`,
`grilling`, or `task`. ([Wayfinder source](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md))

The ticket types have different autonomy rules:

- `research` is AFK and is explicitly delegated to a research subagent;
- `prototype` is human-in-the-loop because the artifact exists to elicit a
  human reaction;
- `grilling` is human-in-the-loop conversation;
- `task` may be AFK when an agent can do it, otherwise it gives the human a
  precise checklist.

A HITL agent may not stand in for the human. ([Wayfinder ticket types](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md#ticket-types))

Wayfinder defines an unblocked ticket as one whose blockers are closed and the
frontier as open, unblocked, unclaimed children. A session claims a ticket
before work so concurrent sessions skip it. The source says never to resolve
more than one ticket per session except research tickets, and notes that users
may work unblocked tickets concurrently. ([Wayfinder tickets and invocation](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md#invocation))

Resolving a Wayfinder ticket is a tracker transaction: post the resolution,
close the ticket, add a context pointer to the map, and then reconcile newly
visible fog, new tickets, invalidated tickets, and newly out-of-scope work.
Charting the initial map similarly creates tickets first and wires dependencies
in a second pass. ([Wayfinder work-through process](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md#work-through-the-map))

Wayfinder is planning by default. It should produce decisions rather than
deliverables and stop when nothing remains to decide before implementation.
Matt's first-party walkthrough says the completed map can then be turned into a
spec, with the original tickets retained as primary sources. ([Wayfinder source](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md#plan-dont-do),
[Matt Pocock's v1.1 walkthrough](https://www.aihero.dev/skills/skills-changelog-v1-1-wayfinder-to-spec-to-tickets-grilling-improvements#after-wayfinder-completes))

### `to-spec`: one synthesis transition

`to-spec` consumes the current conversation and codebase understanding, explores
the repository if needed, respects domain vocabulary and ADRs, identifies the
highest practical test seams, confirms those seams with the user, then publishes
one spec with problem, solution, user stories, implementation decisions, testing
decisions, out-of-scope items, and further notes. It explicitly says not to
re-interview the user. ([`to-spec` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md))

This makes `to-spec` a stage transition, not a queue of per-ticket jobs, unless
the repository independently contains several completed maps that each need a
spec. It has a human confirmation point for the proposed test seams.

### `to-tickets`: one decomposition transition that creates a frontier

`to-tickets` reads an agreed plan, spec, or conversation, optionally explores
the codebase, and drafts tracer-bullet tickets. Each ordinary ticket must be a
narrow but complete end-to-end slice, independently demoable or verifiable, and
sized for one fresh context window. Each ticket declares its blockers; no
blockers means it can start immediately. Wide mechanical refactors instead use
an expand-migrate-contract sequence. ([`to-tickets` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md))

Before publishing, the skill presents the proposed split and blockers and asks
the user to approve granularity and dependencies. It then publishes one tracker
item per ticket and defines the implementation frontier as tickets whose
blockers are all done. It explicitly says not to close or modify the parent
issue. ([`to-tickets` process](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md#process))

As with `to-spec`, decomposition itself is normally one transition job. The
multi-agent queue exists after it publishes implementation tickets, not while
several agents independently rewrite the same spec into competing ticket sets.

### `implement`: one ticket per isolated session

The `implement` skill implements the supplied ticket or spec, uses TDD at
pre-agreed seams where possible, typechecks and runs focused tests regularly,
runs the full suite at the end, invokes code review, and commits to the current
branch. ([`implement` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md))

Matt's official documentation is more explicit about session shape: one run
covers one ticket, and tickets produced by `to-tickets` are intended for separate
fresh contexts. `implement` does not create a branch and does not close or update
the tracker ticket after committing. ([official `implement` documentation](https://github.com/mattpocock/skills/blob/main/docs/engineering/implement.md))

### The documented end-to-end flow

Matt describes the main lifecycle as grilling, spec, tickets, implementation,
and code review. Tickets spread development over multiple agent sessions, each
focused on one ticket, and each ticket is implemented in a separate coding
session. Wayfinder is the larger-planning on-ramp that hands a completed map to
the normal spec flow. ([Matt Pocock's v1.1 walkthrough](https://www.aihero.dev/skills/skills-changelog-v1-1-wayfinder-to-spec-to-tickets-grilling-improvements#complete-development-lifecycle-flow))

The repository's own router makes the context boundary explicit: keep grilling,
`to-spec`, and `to-tickets` in one unbroken context where possible; then start
each `implement` ticket in a fresh context. It also says a cleared Wayfinder map
merges at `to-spec` rather than going straight to implementation, except when the
effort turned out genuinely small. ([`ask-matt` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/ask-matt/SKILL.md))

All four upstream skills use `disable-model-invocation: true`; their documented
interface is explicit human invocation. The proposed orchestrator is therefore
an intentional extension that dispatches them under the user's explicit request,
not behavior already provided by Matt's workflow. ([Wayfinder](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md),
[`to-spec`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md),
[`to-tickets`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md),
[`implement`](https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md))

## Sourced Herdr facts

Herdr models sessions, workspaces, tabs, panes, and recognized agents. Its CLI
and local socket API allow one agent to create work for other agents, inspect
their state, and collect results. Pane commands operate raw terminals; agent
commands add agent identity and lifecycle interpretation. ([Herdr agent guide](https://github.com/herdrdev/herdr/blob/master/website/agent-guide.md),
[Herdr automation documentation](https://github.com/herdrdev/herdr/blob/master/website/src/content/docs/agent-automation.mdx))

The official Herdr skill establishes these orchestration invariants:

- Control is allowed only from inside Herdr (`HERDR_ENV=1`).
- The installed binary's help is authoritative for current syntax.
- `agent start` needs an existing idle shell pane; it does not create layout.
- Agent names must be unique and follow `[a-z][a-z0-9_-]{0,31}`.
- `agent prompt --wait` settles on `idle`, `done`, or `blocked`.
- A `blocked` state means Herdr recognized an approval or question UI. The
  orchestrator must inspect the UI and ask the user before answering it.
- `unknown` does not prove completion. `done` is an unseen, completed idle state;
  `idle` is ready for input after its tab has been seen.
- After a failed wait or a block, inspect `agent get` and `agent read` before
  deciding what to send.
- Background work should use `--no-focus`; callers should use explicit pane IDs,
  unique agent names, or `--current`, and parse returned IDs rather than guess.

([official Herdr skill](https://github.com/herdrdev/herdr/blob/master/skills/herdr/SKILL.md))

The installed Herdr `0.8.2` help on this machine confirms the relevant command
surface: `pane split`, `agent start`, `agent prompt`, `agent wait`, `agent get`,
`agent read`, and `worktree create/open/list`. This is a local observation made
on the research date, not a claim that older or future versions have identical
flags.

Herdr's Git worktree support creates or opens a checkout as a normal Herdr
workspace. `worktree create` checks out an existing local branch or creates one
from `--base`/`HEAD`, and can avoid changing focus. Removing a worktree is an
explicit operation, does not delete its branch, and requires force if Git
rejects a dirty removal. ([Herdr 0.8.0 CLI reference](https://github.com/herdrdev/herdr/blob/master/docs/versions/0.8.0/website/src/content/docs/cli-reference.mdx#worktrees))

For Codex specifically, the Herdr integration reports native session identity
for restart/resume, while lifecycle state still comes from Herdr's screen
manifest detection. Therefore the orchestrator must treat lifecycle status as
the control signal Herdr documents, not infer success merely from session
identity. ([Herdr integrations documentation](https://herdr.dev/docs/integrations/#codex))

## Recommendations and inferences for the proposed Codex skill

Everything in this section is a design recommendation inferred from the sourced
contracts above, not behavior promised by Matt Pocock's skills or Herdr.

### 1. Make project analysis deterministic and explainable

At the project root, the orchestrator should:

1. Verify it is in a Git/project root and inside Herdr before offering dispatch.
2. Read repository instructions plus `docs/agents/issue-tracker.md`, domain-doc
   rules, and triage labels. If tracker configuration is absent, report that
   `setup-matt-pocock-skills` is the required prerequisite rather than guessing
   a remote tracker; a clearly established local `.scratch/` layout may be used
   only according to the official local fallback.
3. Query tracker artifacts and construct a small state report with evidence:
   active Wayfinder map(s), open decision frontier, completed map(s) awaiting a
   spec, spec(s) awaiting decomposition, and implementation frontier.
4. Show why it chose the stage and any ambiguity before offering work.

Recommended precedence for one active effort:

```text
open Wayfinder frontier or unresolved Wayfinder fog -> wayfinder
completed map with no downstream spec               -> to-spec
approved spec with no implementation ticket set     -> to-tickets
published implementation ticket set                 -> implement
```

This cannot be inferred reliably from a single label or file. In particular,
`to-spec` applies `ready-for-agent`, and `to-tickets` deliberately leaves the
parent unchanged. The skill should use relationships, artifact contents, and
tracker configuration together. When several active maps/specs exist or lineage
is unclear, selection materially changes the work and should be left to the
user.

The parent spec must never be treated as an implementation-frontier ticket just
because it has `ready-for-agent`. Matt's documentation calls that label an input
designation, warns that AFK pollers otherwise try to build the whole spec, and
recommends explicitly excluding the parent or stripping the label after
`to-tickets`. ([official `to-spec` documentation](https://github.com/mattpocock/skills/blob/main/docs/engineering/to-spec.md#common-questions))

### 2. Offer stage-appropriate choices

For Wayfinder and implementation, present the ordered frontier by ticket title
and offer:

- a user-selected count from 1 through `min(5, frontier size)`; or
- all currently unblocked, unclaimed tickets.

“All” should mean the current frontier snapshot, not an open-ended promise to
auto-dispatch tickets that become unblocked later. After convergence, the
orchestrator can re-analyze and offer the new frontier. This bounds external
mutation and lets the user inspect decisions between waves.

For `to-spec` and `to-tickets`, offer the single next conversion job (or a choice
among several independent completed maps/specs). Do not manufacture five agents
to write competing versions of one spec or one ticket graph.

### 3. Preserve Wayfinder's AFK/HITL distinction

The dispatcher should parallelize AFK `research` tickets and agent-doable AFK
`task` tickets. It may open a Herdr panel for `prototype` or `grilling`, but must
tell the user that the panel needs live participation and must never let another
agent impersonate the user. A HITL `task` likewise becomes a surfaced checklist,
not an autonomous agent job.

Each Wayfinder worker gets exactly one decision ticket and must claim it before
work. Its brief should include the map URL/path, ticket URL/path, stage, required
skills, tracker conventions, and the rule that it must perform the full
resolution transaction and reconcile newly visible fog. The orchestrator must
re-query after each resolution because closing one ticket can change the
frontier and ticket graph while sibling agents are still running.

### 4. Isolate concurrent implementation

Multiple implementation agents must not edit and commit in the same checkout.
Because `implement` commits to the current branch and does not create one, the
orchestrator should create one Herdr-managed Git worktree and branch per selected
implementation ticket, start one named agent in each worktree workspace, and
record the branch/worktree mapping. This is necessary even for currently
unblocked tickets: dependency independence does not prove filesystem or Git-index
independence.

The convergence strategy is a separate policy choice. Safe default: workers
commit their ticket branches but the orchestrator does not merge, cherry-pick,
push, delete worktrees, or close tickets without explicit scope for those
actions. It reports commits and any integration order/conflicts to the user.

### 5. Treat orchestration as a monitored wave

Maintain an in-memory table per dispatched ticket:

```text
ticket -> stage -> claim -> agent name -> pane/workspace -> branch/worktree
       -> Herdr state -> last observation -> outcome/commit -> required action
```

After prompting every worker, wait on agents in bounded intervals and re-read
the entire live set. State handling should be:

- `working`: continue monitoring;
- `done` or `idle`: read output, verify the tracker/branch result, and classify
  success or incomplete work from evidence rather than lifecycle state alone;
- `blocked`: immediately inspect the recent UI, summarize the exact approval or
  question to the user, and do not answer on their behalf;
- `unknown`: inspect and keep monitoring; never mark complete from this state;
- agent exit/start failure/stalled prompt: report the operational failure and
  preserve its ticket/branch for recovery rather than silently redispatching.

The root Codex instance remains the orchestrator. Worker prompts should forbid
spawning additional ticket agents unless the ticket's own selected skill
explicitly requires a bounded research subagent; otherwise the orchestration
tree becomes invisible to the root.

### 6. Verify workflow outcomes, not terminal text alone

For Wayfinder, completion evidence is the claimed ticket's resolution comment or
answer, closed/resolved state, map context pointer, and reconciled fog/tickets.
For `to-spec`, it is one published spec after the seam confirmation. For
`to-tickets`, it is the approved set with dependency edges. For implementation,
it is the worker's commit plus test/review evidence; tracker closeout remains a
separate explicit action because `implement` does not do it.

## Implementation questions that materially change the skill

1. **Tracker scope:** should the first version support both configured GitHub and
   local Markdown trackers, or only the tracker convention present in the
   current project?
2. **HITL dispatch:** when a frontier includes Wayfinder `prototype`, `grilling`,
   or HITL `task` tickets, should the skill create panels and ask the user to
   enter them, or exclude them from “AFK next tickets” and surface them as the
   blocking human actions?
3. **Implementation convergence:** should implementation workers stop after
   committed worktree branches (safest), or is the orchestrator also authorized
   to integrate branches and update/close tracker tickets after verification?
4. **Meaning of “all”:** is one bounded snapshot of the current frontier the
   intended meaning, or should the skill keep dispatching newly unblocked waves
   until the stage completes? The latter is a materially broader, long-running
   factory loop and needs an explicit stopping/approval policy.
5. **Stage selection:** when several maps/specs are active, should the skill ask
   which effort to drive, or use a project-specific priority convention that is
   recorded in tracker configuration?

## Primary sources

- [Matt Pocock skills repository](https://github.com/mattpocock/skills)
- [Matt Pocock's v1.1 workflow walkthrough](https://www.aihero.dev/skills/skills-changelog-v1-1-wayfinder-to-spec-to-tickets-grilling-improvements)
- [Herdr repository and official skill](https://github.com/herdrdev/herdr)
- [Herdr documentation](https://herdr.dev/docs/)
