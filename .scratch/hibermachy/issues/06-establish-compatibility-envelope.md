# Establish the compatibility envelope

Type: research
Status: resolved
Blocked by:

## Question

What versioning, manifest, configuration-schema, extension-file, systemd, Quickshell, and hardware-capability signals can Hibermachy use to declare, detect, and test its supported Omarchy 4.x compatibility envelope?

## Answer

The tested baseline is Omarchy `4.0.1-1`, Quickshell `0.3.1`, and systemd `261`. The manifest cannot enforce dependency versions, so Hibermachy must publish its compatibility range, preflight it, and feature-probe at runtime. Later Omarchy 4.x and dev builds are best-effort only after probes; other majors leave automatic actions disarmed.

Use logind's `CanSuspend`, `CanHibernate`, and `CanSuspendThenHibernate` as authoritative non-destructive gates, with Omarchy/sysfs checks used only for diagnostics. Invalid or unknown config/schema and missing required shell/Quickshell contracts fail closed; missing hibernation safely degrades to ordinary suspend. Static checks cannot certify hardware, so the eventual release gates require repeated controlled hardware cycles.

Research context: branch `research/compatibility-envelope`, commit `c198999`, report `docs/research/compatibility-envelope.md`.
