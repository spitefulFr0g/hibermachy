# Constrain privileged configuration

Type: grilling
Status: resolved

## Question

What privilege boundary may Hibermachy use to edit systemd's system-wide hibernate delay without granting the Quickshell plugin persistent administrative access?

## Answer

- Idle-to-suspend configuration remains unprivileged.
- System-wide sleep-policy changes go through a separately installed, root-owned helper that runs only for one requested operation and exits.
- The helper exposes only bounded, fixed operations such as setting the delay, setting the on-AC boolean, and resetting Hibermachy's drop-in.
- It accepts no caller-selected paths, commands, free-form configuration, or shell fragments.
- Polkit requires administrator authentication on every change; there is no passwordless or retained authorization.
- The UI labels the hibernate delay as system-wide and indicates that applying a change requires authorization.
- Reading effective state and invoking logind's existing suspend-then-hibernate operation do not require custom persistent privilege.

## Comments

The user explicitly accepted the constrained-helper model after reviewing its security implications.
