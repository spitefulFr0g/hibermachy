# Ticket 25 — AC5 accessibility determination

Issue: #25 (`23: Qualify one immutable candidate in clean-room gates`)
Status: **determined 2026-09-20.** The sign-off block at the end is complete and
this determination is in force.

## The criterion

> Keyboard-only and assistive-technology accessibility sign-off covers focus,
> cancellation, authentication return, announcements, scaling, contrast,
> non-color distinctions, and requested/effective comparisons.

## The determination

Two separate calls, recorded together because they both land on AC5.

**1. Assistive-technology verification is out of scope for this release.** The
owner has removed it from scope on 2026-09-20. No screen reader will be
installed, and no screen-reader verification will be performed or scheduled for
this release. This is a scope decision, not a deferral: there is no carried-
forward obligation and no pending item.

**2. AC5 is accepted as unmet.** No operator session of any kind is being
scheduled, so the keyboard-only half is also unevidenced. The criterion is
recorded as unmet rather than as satisfied by the automated checks below.

## What exists as evidence

Automated and static only. No operator session occurred.

- `HBR-CHK-PANEL-ANNOUNCE-001` lifts both announcing `Text` elements out of the
  shipped panel source and drives them through real QML binding evaluation on
  Qt 6.11.2. It confirms the first action result is announced, repeats are
  announced, clearing is silent, and a hidden panel is silent.
- `HBR-CHK-PANEL-ANNOUNCE-002` confirms a QML `Accessible.announce` call reaches
  the accessibility bus as an `object:announcement` event with the announced
  text intact. It uses AT-SPI introspection and needs no screen reader. It is
  opt-in behind `HBR_RUN_HOSTED=1` and never runs in the ordinary battery.
- `HBR-CHK-STATIC-006` confirms all three announcing elements carry a matching
  handler.
- Static: foreground-on-background contrast measures 11.56:1, passing AA and
  AAA; the single token below 4.5:1 is never used for displayed text. All 17
  focus targets carry non-empty `Accessible.name`.

The two announcement checks predate this scope decision and cost nothing to
keep, so they are retained as passing evidence of what the panel does. They are
not a substitute for the criterion and are not described as accessibility
verification.

**Defects found and fixed during this work.** The requested-versus-effective
comparison carried no announcement handler at all. Separately, all three
handlers gated on a stale `visible` binding, so the first action result after an
empty state was never announced and clearing it announced an empty string.

## What is consequently unclaimed

No accessibility sign-off is claimed. The following are **NOT RUN**, and the
first group will not be run:

*Out of scope — assistive technology:*

- Whether a screen reader presents any announcement usefully.
- Screen-reader behaviour at any point in the panel.

*Unevidenced — no operator session:*

- Keyboard-only navigation through the 17 focus targets, including focus
  visibility, ordering, and trapping.
- Confirmation dialog focus behaviour: default focus, arrow-key movement,
  Escape cancellation, and focus return to the invoking control.
- Focus return after the `pkexec` authentication dialog, cancelled and
  authorized.
- Behaviour at 150–200% text scale.
- Contrast against the theme actually active on the release machine rather than
  the fallback tokens.

## Consequences binding on the release

- No accessibility sign-off, conformance, or WCAG claim may be made anywhere.
- The release must not describe the panel as accessible or screen-reader tested.
- The issue text for AC5 still reads as written. This determination does not
  amend it; it records that the owner qualified without it. Whoever closes #25
  should say so explicitly rather than tick the box.

## Sign-off

```
Determination:  assistive technology out of scope; AC5 accepted as unmet
Rationale:      The owner removed screen-reader verification from scope for this
                release and is not scheduling an operator session. Automated
                announcement evidence is recorded for what it covers; keyboard
                and screen-reader behaviour remain unevidenced and are stated
                as such.
Owner:          spitefulFr0g
Date:           2026-09-20
```

Recorded from the owner's explicit instruction during the 2026-09-20 working
session. This is a determination entry, not a cryptographic signature.

**In force.**
