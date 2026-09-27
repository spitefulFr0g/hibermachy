# 24: Run the attended hardware gate and promote unchanged bits

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** An explicitly armed attended procedure verifies physical staged sleep and recovery on the designated battery-equipped machine, restores initial state, and promotes only the unchanged qualified candidate.

**Blocked by:** 23: Qualify one immutable candidate in clean-room gates.

**Status:** ready-for-agent

- [ ] The operator explicitly arms the procedure after a save-work warning; the gate identifies the target, records initial policy and configuration, and never lets capability detection itself trigger sleep.
- [ ] Three consecutive successful staged-sleep, observed hibernation, and same-session resume cycles collectively include automatic request, manual request, and AC deferral followed by disconnect.
- [ ] Separate attended cases exercise early wake, Stay Awake suppression, compositor inhibition, system-inhibitor refusal, fresh-activity re-arm, reload while latched, and deliberate suspend fallback.
- [ ] Hibernation evidence combines an external pre-sleep session checkpoint, external observation of powered-down or hibernated state, same-session restoration, and sanitized corroborating system evidence; Hibermachy Completed or free-form journals cannot certify it.
- [ ] Any unexplained anomaly blocks promotion and restarts the consecutive-cycle count only after investigation; initial policy and configuration are verified restored afterward.
- [ ] Promotion publishes the sanitized verification record, promotes the unchanged candidate, and smoke-checks public metadata, artifacts, checksums, downloads, and lifecycle discovery.
- [ ] Published artifacts are immutable per version; failure creates a new candidate identity and post-release defects are corrected only in a new release.
