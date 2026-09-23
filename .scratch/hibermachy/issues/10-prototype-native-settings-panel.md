# Prototype the native settings panel

Type: prototype
Status: resolved
Blocked by: 07, 08, 13

## Question

What panel hierarchy, controls, status language, authorization affordance, fallback presentation, and confirmation behavior make Hibermachy's settings feel native to Quattro and safe to operate?

## Answer

Use the prototype's **Variant A: Single-sheet settings**. Hibermachy is one
compact, vertically scrolling Quattro panel, sized and styled like the stock
roughly 380-pixel panels. It uses the native hero, separators, uppercase section
headers, theme roles, controls, focus treatment, and keyboard behavior rather
than inventing an application-style settings window.

The panel hierarchy is:

1. A **Sleep & Hibernation** hero that names Hibermachy, gives the current
   operational state in a short semantic pill, and explains what the next
   automatic or manual request would do.
2. **Automatic staged sleep**, containing the automatic-policy toggle and idle-
   delay control. These edit a user-policy draft and have their own **Save
   automatic policy** button. Saving requires no authentication and never
   implies that system policy was also applied.
3. **System policy**, containing the hibernate-delay control and **Hibernate
   while plugged in** toggle. A nearby notice labels these as system-wide, and
   **Apply system policy…** submits both values as one pair through the
   authenticated helper. If Hibermachy already owns policy, **Reset…** is also
   available.
4. **Current status**, with distinct rows for automatic-policy enablement,
   requested system policy, effective system policy, current sleep
   executability, Stay Awake, and any active blocking reason.
5. A secondary **Suspend then hibernate now…** action at the bottom. The
   Super+Space System entry remains the primary menu location for this action;
   the panel copy is a convenience inside the configuration surface.

Duration controls present the prototype's common friendly choices while
respecting the already-specified bounds: idle delay offers 5, 15, and 30
minutes, then 1, 2, 4, 8, and 24 hours; hibernate delay offers 15 and 30
minutes, then 1, 2, 4, 8, and 24 hours, and 7 days. A valid non-preset value
loaded from configuration is displayed as a custom friendly duration and is
not rounded or rewritten merely by opening the panel. Persisted mutations still
normalize to the whole-second schema. Controls edit drafts; their owning action
is enabled only when that commit domain is dirty.

Authorization and confirmation follow the mutation's consequence:

- Saving user policy needs neither authorization nor an extra confirmation.
- Applying system policy shows the exact hibernate delay and AC behavior, then
  opens Omarchy's Polkit authentication flow. That review plus authentication
  is the confirmation; cancellation leaves requested policy unchanged.
- Reset first explains that only Hibermachy's owned systemd drop-in will be
  removed and that plugin activation and user policy remain, then requires
  authentication.
- Manual staged sleep always gets an explicit confirmation because it acts
  immediately. The dialog states whether the request will stage hibernation or
  use suspend-only fallback, that manual intent bypasses Stay Awake and
  compositor idle inhibition, and that system sleep inhibitors remain honored.

Use the prototype's state language and semantic emphasis:

- **Ready**: staged sleep is executable.
- **Suspend fallback**: hibernation is unavailable; preserve policy and intent,
  explain that requests suspend only, and change the manual confirmation verb
  to **Suspend only**.
- **Automation paused**: Stay Awake suppresses automatic staged sleep while the
  manual action remains available.
- **Unavailable now**: a system sleep inhibitor or absence of both staged sleep
  and suspend prevents a request. Show the blocking reason and disable the
  manual action when the blocker is already known.
- **Policy differs**: requested and effective system policy disagree. Show both
  value pairs and the overriding source when available; applying again must not
  imply that Hibermachy can defeat administrator precedence.

An enabled automatic policy with missing, invalid, or unreadable system policy
is shown as intended but **Not ready** and remains disarmed. Successful saves or
applies that require fresh activity say so without pretending automation is
already armed. Known operational fallbacks belong in this panel decision;
detailed error taxonomy, history, diagnostics, and recovery copy remain with
**Define failure handling and observability**.

## Prototype

[Interactive native settings-panel variants](../../../prototypes/native-settings-panel/index.html) — branch `prototype/native-settings-panel`, commit `04688be`, file `prototypes/native-settings-panel/index.html`.

## Comments

The user selected Variant A after reviewing the interactive prototype.
