# Hibermachy pause checkpoint — 2026-09-14

Work is safely paused before attended accessibility and hardware testing.

- PR #28 is merged at `2bb7cb344e2330799ddb6713d58b735eb5a6de4c`.
- Final merged source archive is signed and verified with fingerprint
  `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`.
- Final archive SHA-256:
  `09180240e9b038dfb77048895d752b6fc7dbda32548ed6a48c9fe7d5fdb74264`.
- Final package SHA-256:
  `b25a35a31f81e1cbc461d9bb6c32782988ad1234773954dabefba50b0ecf589a`.
- Signature/checksum verification, unprivileged package build, content inspection,
  33 Rust tests, ordinary gates, 17 hosted scenarios, and the 2,000-transition
  soak passed.
- Existing-machine discovery, activation/disable, panel visibility, policy
  persistence, authenticated apply/readback, cancellation, and reset passed.
- The temporary test policy is removed. Requested/effective policy is absent.
- Automatic staged sleep is disabled. No operation is running and no real sleep
  or hibernation test has started.

Resume with the agreed four-stage attended run: save-work preflight,
keyboard/accessibility checks, suppression/inhibitor checks, then three attended
staged-sleep/hibernate/resume cycles and restoration. The wizard template was
copied to `handoff/attended-release-2bb7cb3.sh`, but its stages have not been
authored yet. Finish that script before running it.

Issues #25, #26, and parent #2 remain open. No release has been published.
