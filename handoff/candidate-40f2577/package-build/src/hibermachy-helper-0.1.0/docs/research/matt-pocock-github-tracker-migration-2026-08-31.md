# Matt Pocock workflow: GitHub tracker migration

Date: 2026-08-31

## Question

How should Hibermachy switch from the local Markdown fallback to a GitHub-based Matt Pocock workflow, and where do pull requests fit?

## Findings

- The official setup process is prompt-driven: inspect the repository, recommend the tracker matching its remote, present the configuration, confirm it, then write. With a GitHub remote, GitHub Issues is the recommended tracker. [Setup Matt Pocock's Skills](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)
- On GitHub, publishing to the tracker means creating GitHub issues. Specs are issues, implementation tickets are issues, native sub-issues express parentage, and native issue dependencies express blockers. [GitHub tracker template](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/issue-tracker-github.md), [To Tickets](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md)
- GitHub supports native sub-issues and blocked-by relationships through its REST API. [Sub-issue endpoints](https://docs.github.com/en/rest/issues/sub-issues), [Issue-dependency endpoints](https://docs.github.com/en/rest/issues/issue-dependencies)
- The implementation skill consumes one ticket per fresh session, tests and reviews it, and commits to the current branch. It neither creates a branch nor opens a pull request, and it does not close the issue. [Implement guide](https://github.com/mattpocock/skills/blob/main/docs/engineering/implement.md)
- Pull-request creation and merge closeout therefore require a repository-specific integration convention after implementation. The tracker template's “PRs as a request surface” flag concerns triaging external PRs and is unrelated to implementation PR publication.
- The upstream workflow defines no automatic local-Markdown-to-GitHub migration. An existing effort needs an explicit choice between complete historical import and active-work migration.

## Decision

GitHub Issues becomes authoritative for the approved parent spec and its 24 implementation tickets. The tickets are native sub-issues with native blocking relationships and `ready-for-agent` labels. The completed local Wayfinder map, its 14 resolved decision tickets, and the local ticket copies remain unchanged as historical evidence.

Hibermachy adds a repository convention of one isolated implementation branch, worktree, and pull request per ticket. The issue closes on merge so GitHub's dependency graph exposes the next frontier.
