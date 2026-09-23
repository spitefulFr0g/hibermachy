# Token-efficient Herdr orchestration

## Question

How can a long-lived Codex orchestrator keep the Wayfinder -> to-spec ->
to-tickets -> implement lifecycle moving without importing worker transcripts
into its own context?

## Findings

1. Herdr workers remain separate agent sessions. Herdr exposes lifecycle state
   (`working`, `blocked`, `done`, `idle`, and `unknown`) independently from
   terminal output. `herdr agent wait` and `herdr agent get` are therefore the
   appropriate control-plane primitives.
2. Transcript transfer is explicit. `herdr agent read` and `herdr pane read`
   return rendered terminal text; recent-history reads may collect multiple
   alternate-screen pages. Those commands should not be part of normal
   monitoring.
3. Codex appends tool results to the conversation used for later inference.
   Consequently, every pane read returned to the orchestrator consumes context,
   even though the worker session itself remains isolated.
4. Herdr supports status-change waits and socket event subscriptions. A small
   deterministic watcher can wait outside the model loop and emit only a compact
   state transition, avoiding repeated model-driven polling.
5. Matt Pocock's workflow already treats the issue tracker and project artifacts
   as durable state. The Wayfinder map is an index, while decisions live on their
   tickets. This makes the tracker/artifacts a better worker-to-orchestrator data
   plane than terminal transcripts.
6. Matt Pocock's `implement` skill ends at code review and a commit and does not
   close its work item. A thin outer dispatch contract must let the same worker
   perform normal tracker completion bookkeeping after `implement` finishes,
   without modifying the skill's internal sequence.

## Recommended architecture

- Use Herdr only as the attention/control plane: identity, `working`, `blocked`,
  `done`, and `unknown`.
- Use tickets, specs, commits, tests, and other project artifacts as the durable
  data plane.
- Package a deterministic multi-worker watcher that emits only changed state.
- Do not read worker terminal output during normal progress or completion.
- On completion, re-scan narrow tracker metadata and artifact state to compute
  the next frontier.
- On a block, first inspect the worker's normal tracker/artifact state. If the
  blocking UI interrupted before the action was recorded, permit one small
  detection-screen read to identify the required human action.
- Treat `unknown` as an exception requiring bounded diagnosis, never as success.
- Batch routine completion notices; interrupt the user immediately only for a
  block, failed verification, or decision that requires human authority.

## Sources

- OpenAI, "Unrolling the Codex agent loop":
  https://openai.com/index/unrolling-the-codex-agent-loop/
- Herdr, "Agent automation":
  https://herdr.dev/docs/agent-automation/
- Herdr, "CLI reference":
  https://herdr.dev/docs/cli-reference/
- Herdr, "Socket API":
  https://herdr.dev/docs/socket-api/
- Matt Pocock skills, Wayfinder documentation:
  https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md
- Matt Pocock skills, Implement documentation:
  https://github.com/mattpocock/skills/blob/main/docs/engineering/implement.md

## Confirmed design

1. Normal operation performs no transcript reads. One 20-line detection read is
   available only for an otherwise unknowable block or persistent unknown state.
2. A bundled deterministic watcher handles lifecycle polling outside the model
   loop and emits compact state changes.
3. Matt Pocock's configured tracker and artifacts remain the only durable state;
   the dispatcher retains only a small in-memory ledger for the current wave.
4. Human interactions happen directly in the named worker tab.
5. Routine completions are batched; blocks and decisions interrupt immediately.
6. Frontier menus offer a recommended batch, a chosen subset of up to five, or
   all currently unblocked tickets. Newly unblocked work requires another choice.
7. HITL work is offered one at a time; AFK and implementation work may be batched.
