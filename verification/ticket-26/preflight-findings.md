# Ticket 26 hardware pre-flight findings

Gathered 2026-09-20 on the designated machine by read-only inspection, before
the attended gate was armed. No sleep was initiated, no policy was mutated, and
nothing was installed. This is pre-flight evidence only: it does not satisfy any
acceptance criterion of issue #26, and no gate is marked passed here.

Environment: Omarchy 4.0.4-1, Quickshell 0.3.1-1, systemd 261.2-1, kernel
6.19.8-arch1-3-surface, battery and AC adapter both present.

## The two carried-forward risks are resolved in favour of proceeding

The ticket #26 handoff flagged two risks that gated the whole gate. Both are now
answered by observation rather than by inference.

**zram priority does not capture the hibernation image.** zram sits at priority
100 against the swapfile's priority 0, which is the documented shape of the
zram-plus-hibernate problem. It is not a problem here. The kernel selects the
hibernation target from `resume=`/`resume_offset`, not from swap priority, and
`/sys/power/resume` reads back `253:0` with offset `1882657`, resolving to the
swapfile. Ordinary swapping goes to zram; the swapfile stays free for the image.
`/proc/swaps` confirms the swapfile is entirely unused while zram carries the
live swap load, which is the correct arrangement rather than a broken one.

**Image headroom is sufficient.** `/sys/power/image_size` is 3257675776 bytes
(~3.0 GiB) against a wholly free 7.7 GiB swapfile.

**Both are corroborated by hibernations that actually happened.** The retained
journal records three completed hibernation cycles on this machine, including
one spanning 2026-09-14 to 2026-09-19 that resumed into the same boot session
it left. That is direct evidence the hardware, the swapfile, the resume offset
and the encrypted-root resume path all work together, with zram present
throughout.

The `resume` hook is also confirmed active without reading `/boot`, which needs
root: the kernel logs `PM: Image not found (code -22)` at every ordinary boot,
which is the message emitted when the resume path runs and finds no image.

## Two risks the handoff did not know about

**1. A vendor drop-in disables user-session freezing on the sleep units.**

`SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false` is set by
`10-nvidia-no-freeze-session.conf`, shipped under `/usr/lib/systemd` for
`systemd-suspend`, `systemd-hibernate`, `systemd-hybrid-sleep` and
`systemd-suspend-then-hibernate`. systemd itself warns that this
"might result in unexpected behavior, particularly in suspend-then-hibernate
operations" — and `systemd-suspend-then-hibernate.service` is the exact unit
staged sleep drives.

This is distribution-owned configuration, not Hibermachy's, and it applies on
this machine even though it is an Intel-iGPU device. It must be recorded as a
condition of the verified environment. It must not be changed: mutating system
sleep policy is outside the gate's scope and would invalidate the run.

**2. The staged-sleep unit has never run on this machine.**

`systemd-suspend-then-hibernate.service` has no journal entries. Every prior
hibernation here went through `systemd-hibernate.service` directly. The prior
successes therefore corroborate the hardware, the swapfile and the resume path,
but they say nothing about the staged path Hibermachy actually uses. A
first-cycle failure should be investigated as a configuration or platform
question before it is treated as a product defect.

## Two required attended cases have no automated coverage

Two of the seven separate cases required by AC3 are exercised for the first time
by this attended gate, because no merge-gate test drives them:

- **Early wake.** `HBR-SLEEP-EARLY-WAKE` is enumerated in the service source and
  in the reason-code allowlist, but no test in `tests/` exercises it.
- **Reload while latched, same boot.** `HBR-SLEEP-SERVICE-RECREATED` is likewise
  present in source. The sampled tests only seed a *different* boot id, which
  exercises `HBR-SLEEP-BOOT-CHANGED` instead.

Both cases deserve closer attention during the attended run than the five cases
that do have deterministic coverage.

## Limitations of this pre-flight

- `/boot` is not readable without root, so the contents of the built initramfs
  were not inspected. The `resume` hook is declared in
  `/etc/mkinitcpio.conf.d/`, and the kernel's boot-time resume attempt is
  observable, but the built image itself was NOT verified.
- No staged-sleep cycle was performed. Everything above is inspection of
  configuration and of already-retained journal history.
- Hibernation and ordinary suspend are indistinguishable to every signal
  available without an operator watching the machine power down. Nothing here
  certifies hibernation.
