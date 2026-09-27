# Attended compositor inhibition case for issue #26

This case must run against the next frozen release candidate containing the
production inhibitor observation fix from #52. It is not evidence for the
already-public v0.1.0 release. Record the candidate commit, signed source
archive checksum, installed plugin checkout, exact environment versions, and
initial user and system policy before starting. The historical
`handoff/attended-release-625d5a2.sh` and its candidate-bound template are
obsolete; do not use them to qualify current bits.

Save work and obtain the explicit operator arm statement from the issue #26
procedure before any real sleep case. Keep an operator at the machine. Capability
and status checks alone must not initiate staged sleep.

1. Record the current `omarchy-shell dev.hibermachy status` snapshot and outcome
   history. Confirm automatic-policy enablement and a known idle delay. Record
   the initial Stay Awake setting and any compositor inhibition.
2. Turn Stay Awake off. Start a Wayland client that **actually requests** an
   idle inhibitor, such as fullscreen mpv with `--stop-screensaver=always`.
   Confirm its `zwp_idle_inhibit_manager_v1.create_inhibitor` request with a
   private `WAYLAND_DEBUG=client` trace or equivalent compositor evidence.
   A browser video alone is not proof that an inhibitor exists. Do not publish
   raw Wayland traces without sanitizing them.
3. After the short monitor interval, require
   `compositorIdleInhibited=true` and
   `automaticBlockerReasonCode=HBR-COMPOSITOR-IDLE-INHIBITED`. Confirm manual
   staged sleep remains available. These status fields show the product's
   observation; they do not by themselves establish suppression.
4. Produce fresh activity, then keep the inhibitor active and provide no input
   for longer than the configured idle delay. Observe externally that no sleep
   occurred. Compare typed outcome history and system sleep transaction counts
   before and after: no automatic staged-sleep attempt may be submitted.
5. Stop the inhibiting client. Confirm the blocker clears. Restore Stay Awake
   and verify the initial user and system policy and configuration. Record any
   anomaly as a failed case; investigate it before resuming the consecutive
   physical cycle count.

Use the [evidence template](compositor-inhibition-evidence.md) for this case.
It remains `NOT RUN` until the actual idle interval and external observation
are complete. The three required observed-hibernation cycles are separate.
