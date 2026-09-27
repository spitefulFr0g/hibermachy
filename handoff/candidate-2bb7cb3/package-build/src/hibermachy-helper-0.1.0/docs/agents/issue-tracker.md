# Issue tracker: GitHub

GitHub Issues in `spitefulFr0g/hibermachy` are authoritative for specs and tickets. Use the `gh` CLI from this clone so it resolves the repository from `origin`.

The existing local Markdown artifacts under `.scratch/hibermachy/` are historical planning evidence. Preserve them and do not use them for frontier, claim, dependency, status, or closeout decisions.

## Tracker operations

- Create, read, list, comment on, label, assign, and close work through `gh issue`.
- Fetch a referenced issue with its body, labels, relationships, assignees, and comments before acting.
- Specs are open parent issues. Their implementation tickets are native GitHub sub-issues.
- Blocking uses native GitHub issue dependencies. A textual `Blocked by` section is explanatory, not authoritative.
- `ready-for-agent` marks implementation tickets that need no further triage. A decomposed parent spec is excluded from the implementation frontier even when its body records its prior ready status.

## Implementation frontier

The frontier is the parent spec's open implementation sub-issues with no open native blockers and no assignee, in sub-issue order.

Claim one frontier ticket as the first write by assigning it to the driving developer. One implementation session owns one ticket.

## Implementation and pull requests

1. Create an isolated branch and worktree for the claimed ticket from the branch its blockers landed on.
2. Implement and test only that ticket's vertical slice, then commit it on the ticket branch.
3. Run an independent review against the branch point and resolve actionable findings before publication.
4. Push the ticket branch and open one pull request whose body links the parent spec and contains `Closes #<ticket>`.
5. Merge is the closeout boundary: merging closes the ticket and may expose newly unblocked frontier work.

The implementation skill itself ends at a commit. Branch creation, push, pull-request publication, merge, and tracker closeout are explicit repository workflow actions.

## Pull requests as a triage surface

External pull requests are not feature-request tickets and do not enter the issue triage queue.
