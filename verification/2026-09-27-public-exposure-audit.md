# Public exposure audit for v0.1.0 and release candidates

Audit date: 2026-09-27. Issue: [#47](https://github.com/spitefulFr0g/hibermachy/issues/47). Snapshot: `main` at `d6b9b79b5064ad1705eb8d4d8ba7cdebe827038a`, after `git fetch origin`. This is a retrospective review of already-public material, not a security certification or a claim that publication waited for this review.

## Scope and method

- Reviewed the 16 GitHub branch heads, four release tags, current tracked tree (576 files), and reachable public Git history. The tag commits were rc.1 `25730dd686595ca33bf4e574ba84660af1ec269f`, rc.2 `61627f5c652913985acdb882b9bc5c1a4dce83b0`, and rc.3/v0.1.0 `f1ad0912556b92d88fd088df03aea98fd6a9decd`. The fetched remote branches and tags reached 115 distinct commits. A broader local `--all` scan also covered 192 commits, including local-only refs.
- Downloaded all 24 attached assets from the four public releases. Compared each downloaded file's size and SHA-256 with the GitHub Releases API. Inspected every member of the four signed source archives and four recipe archives, including files under `.scratch/`, `handoff/`, documentation, examples, fixtures, generated evidence, candidate package builds, and local machine test records. The exact asset inventory and API digests are below. GitHub-generated tag archives represent the tagged Git trees, which were inspected through Git history.
- Ran Gitleaks 8.30.1 with its default rules on public Git refs, the current directory, and downloaded release assets, with archive depth 2 and fully redacted reports. Also scanned history and current files for private-key blocks, credential-bearing URLs, common token formats, local home paths, email addresses, host or machine identifiers, and network addresses. Manually examined matches and likely exposure paths, including build logs, `.BUILDINFO`, policy/configuration snapshots, and diagnostic notes. A clean pattern scan cannot establish that all sensitive material is absent.
- The public-ref Gitleaks run examined 94 commit patches and produced nine `generic-api-key` matches; the current-tree and release-asset runs produced eight each. All distinct matches were the public signing fingerprint. The broader local `--all` run produced 573 repeated matches from 192 commit patches, also only that fingerprint.
- Checked GitHub's public branches, tags, releases, 48 issue/PR records and two comments/reviews, secret-scanning alerts, Actions runs/artifacts, Pages setting, and wiki availability. Selected credential, private-key, URL, home-path, email, and IPv4 patterns found no matches in the issue/PR discussion. The repository reported zero secret-scanning alerts, zero Actions runs, and zero Actions artifacts; Pages was disabled. Wiki was enabled but the wiki Git endpoint required authentication, so its contents were not verified.
- Inspected all four exported OpenPGP key files with GPG packet listing and isolated keyrings. They contained public-key, public-subkey, user-ID, and signature packets only, with no secret-key packet. Every detached source signature verified against its release's exported public key. This verifies consistency with that key; users still need an independently trusted fingerprint.

## Sanitized findings and disposition

| ID | Classification | Evidence and outcome | Owner/status |
| --- | --- | --- | --- |
| F1 | Confirmed local account and machine metadata disclosure | Tracked `handoff/` build records and verification notes contain absolute home paths; `verification/2026-09-22-staged-sleep-failure.md` contains a prior-boot journal identifier and machine-specific hardware/kernel diagnostics. The values remain in public Git history and release archives. No credential was identified in these records. | `@spitefulFr0g`; current-tree, historical, and release disposition tracked by [#49](https://github.com/spitefulFr0g/hibermachy/issues/49), pending a separately versioned corrected release or explicit acceptance. |
| F2 | Confirmed excessive release archive contents | Every signed source archive includes 727 members, including 47 under `.scratch/` and 562 under `handoff/`. These include local machine test snapshots, candidate package build outputs, and `.BUILDINFO` metadata. Those files were signed as part of the published archive. | `@spitefulFr0g`; archive curation and any coordinated public artifact remediation tracked by [#49](https://github.com/spitefulFr0g/hibermachy/issues/49). Do not silently replace v0.1.0 or RC assets. |
| F3 | Scanner false positives | Gitleaks' `generic-api-key` matches were the public OpenPGP signing fingerprint in scripts and package metadata, including copies in archives. The distinct matched values were checked against the release key's public fingerprint. | Resolved; no rotation indicated. |

No confirmed credential or private-key exposure was found in the examined snapshot. This does **not** prove one never existed or that unexamined surfaces are clean. No credential rotation is indicated by the confirmed findings. The historical path/diagnostic disclosure and published archive scope are still open owner decisions; the existing release files must retain their versioned identity. Wider marketplace promotion should wait for that disposition and updated release artifacts if needed.

## Reproduction

The Gitleaks binary used was the official `v8.30.1` Linux x64 release, checked against its published checksum file. These commands generate local redacted reports; review matches manually without posting values to GitHub.

```sh
git fetch origin
gitleaks git . --log-opts='--remotes=origin --tags' --max-archive-depth=2 --redact=100 --report-format=json --report-path=/tmp/hibermachy-git-audit.json
gitleaks dir . --max-archive-depth=2 --redact=100 --report-format=json --report-path=/tmp/hibermachy-tree-audit.json
for tag in v0.1.0 v0.1.0-rc.1 v0.1.0-rc.2 v0.1.0-rc.3; do
  mkdir -p "/tmp/hibermachy-release-downloads/$tag"
  gh release download "$tag" --dir "/tmp/hibermachy-release-downloads/$tag"
done
gitleaks dir /tmp/hibermachy-release-downloads --max-archive-depth=2 --redact=100 --report-format=json --report-path=/tmp/hibermachy-release-audit.json
gh api repos/spitefulFr0g/hibermachy/releases
```

The final `gitleaks dir` path denotes a parent directory containing the four release download directories. Compare each file against the API `assets[].digest` and `assets[].size`, and inspect archive members and GPG packets separately.

## Exact public asset inventory

The SHA-256 values below are GitHub Releases API digests and matched the downloaded bytes on 2026-09-27.

| Release | Asset | SHA-256 |
| --- | --- | --- |
| v0.1.0 | `SHA256SUMS` | `aedcc172bbbedb0659eca0bb539c07315cecc540f7a5f5dc459d072b9af330d9` |
| v0.1.0 | `VERIFICATION.md` | `71a393343de41474edfb6bc4a8b0353d748eb665f7ae2cc9750eb4a8b0b7835c` |
| v0.1.0 | `hibermachy-helper-0.1.0-recipe.tar.gz` | `9dcb0b0cbae53cfd8ee2e20beefe54b0fc6fa7a68e9ee196d63834b3c6d2b7d5` |
| v0.1.0 | `hibermachy-helper-0.1.0.tar.gz` | `ca0f257b279b3555ea72d491802d3f99d2c30726e1e7a1b21ecf77008104e8bb` |
| v0.1.0 | `hibermachy-helper-0.1.0.tar.gz.sig` | `91248f424132d93e8aff5b94c3da694a2e6e4fad98281288e7e81f96cdf4d65d` |
| v0.1.0 | `hibermachy-release-key.asc` | `43b191b725a3fc1a1521f9d64f224713bb502b65357fe9cabceb8e314e821b68` |
| v0.1.0-rc.1 | `RECIPE-SHA256SUMS` | `6d5d315d98a30b28f0590e1e2d553c216dfd2cc310a4dde2904ad38453b8b1ea` |
| v0.1.0-rc.1 | `SHA256SUMS` | `c37b0495baec4210c92202a7ca6e9d82652453fc841a7035bd52304ed376f593` |
| v0.1.0-rc.1 | `hibermachy-helper-0.1.0-rc.1-recipe.tar.gz` | `354214cb0848a6d945201d40804ba5d3311a8b284219e8f241d141ae0e3a91db` |
| v0.1.0-rc.1 | `hibermachy-helper-0.1.0.tar.gz` | `5cc565ee590fa99880b20791ddded04ba947e408e868a66f10d7465cf38835e3` |
| v0.1.0-rc.1 | `hibermachy-helper-0.1.0.tar.gz.sig` | `ac264abb5c9dc0ba90e2959d18f5cc9e34a83f87b334f0a9b21a06ba81f2f584` |
| v0.1.0-rc.1 | `hibermachy-release-key.asc` | `43b191b725a3fc1a1521f9d64f224713bb502b65357fe9cabceb8e314e821b68` |
| v0.1.0-rc.2 | `RECIPE-SHA256SUMS` | `49d7cc60cf2e5fbdacfe18b3652f18e8df759540827cd71e7067d969df9318af` |
| v0.1.0-rc.2 | `SHA256SUMS` | `800750f2e033530c19f35d86404f92b8bdf14a2dd73dda4c4ec47a3382bca3d1` |
| v0.1.0-rc.2 | `hibermachy-helper-0.1.0-rc.2-recipe.tar.gz` | `b5b5d1dafde4584f1d995bd095fe49cc69e35de6a7897b8abd5c73939ebf2c63` |
| v0.1.0-rc.2 | `hibermachy-helper-0.1.0.tar.gz` | `faa79a7c77ba262c161f8b2436474a72a319109baba93692e478089d28b72e0a` |
| v0.1.0-rc.2 | `hibermachy-helper-0.1.0.tar.gz.sig` | `2c946a1620d19830a80f68ddbfd49d706eb8b6722b1d698cecd297d89b1daaaa` |
| v0.1.0-rc.2 | `hibermachy-release-key.asc` | `43b191b725a3fc1a1521f9d64f224713bb502b65357fe9cabceb8e314e821b68` |
| v0.1.0-rc.3 | `RECIPE-SHA256SUMS` | `770ba7834b567025b3816793a6588a078accc8a90d4a3156b41df3fad26a1790` |
| v0.1.0-rc.3 | `SHA256SUMS` | `f42db76dbe811f2d7ddf6adb6a12e5e21a2ae50073c86c54c7709fb1561b8a13` |
| v0.1.0-rc.3 | `hibermachy-helper-0.1.0-rc.3-recipe.tar.gz` | `fd3cc56e5486f1ba2b098927f581ed9f8440f61cf65f1b687434ae6a013bc66f` |
| v0.1.0-rc.3 | `hibermachy-helper-0.1.0.tar.gz` | `ca0f257b279b3555ea72d491802d3f99d2c30726e1e7a1b21ecf77008104e8bb` |
| v0.1.0-rc.3 | `hibermachy-helper-0.1.0.tar.gz.sig` | `91248f424132d93e8aff5b94c3da694a2e6e4fad98281288e7e81f96cdf4d65d` |
| v0.1.0-rc.3 | `hibermachy-release-key.asc` | `43b191b725a3fc1a1521f9d64f224713bb502b65357fe9cabceb8e314e821b68` |

## Public branch heads

These GitHub branch heads were included at the audit snapshot.

| Ref | Commit |
| --- | --- |
| `chore/github-tracker-setup` | `eda2dd01fde45a0fe45806fa13f30539f36fc76f` |
| `docs/v0.1.0-release-record` | `78ddfe33ef8c4e6ca9f235d40e351674783aa535` |
| `fix/31-automatic-activity` | `cd7f459cd25ec7e5a76d1afeb733a7d51d3f486e` |
| `fix/32-wifi-restore` | `89c939baaba4dce369e6530022029952c88c9e75` |
| `fix/34-wifi-staged-transaction` | `78f147159a4b6b932669a82e8d6d2327fb737bfa` |
| `fix/36-lifecycle-policy-isolation` | `0685eb344d21763dfaf1747e4100ceaebcc0c771` |
| `fix/42-lifecycle-display` | `954fea9c019b6e78d3d400f2238b9b8925493f58` |
| `fix/44-logind-inhibition` | `bd109eae28f8dbc821f9cd1d7ab55c95da841366` |
| `fix/integration-reconciliation` | `fd652e4a93f1e78de8f8f4d9cf909e2a7c17bd08` |
| `fix/menu-visibility-guard` | `f352a687a72f22397d7475d871b6b6aaec59f586` |
| `fix/native-service-activation` | `6596986d36e57748d147417997d77163171b900b` |
| `impl/29-observed-lid-action` | `3655010ad3233601e95d6fc3bb717a3cc452855a` |
| `main` | `d6b9b79b5064ad1705eb8d4d8ba7cdebe827038a` |
| `release/0.1.0-preparation` | `0713baacc4e025f98336cffe481746a19f73faab` |
| `release/v0.1.0` | `8d5747f5e28d2b40d9057c2560dee0819ca3fff6` |
| `ticket-26-attended-hardware-gate` | `43628c38a2b87e9a169eb4e4852714099f2e7f43` |
