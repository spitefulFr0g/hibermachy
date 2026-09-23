# Define Hibermachy's product boundary

Type: grilling
Status: resolved

## Question

What destination, audience, behavior, timing semantics, fallback, power model, and compatibility promise define Hibermachy's first release?

## Answer

- Wayfinding ends with an implementation-ready specification; implementation follows separately.
- Hibermachy is a public, independently installable third-party plugin designed so its ideas could later be upstreamed.
- Automatic staged sleep is triggered by user idle. A separate manual **Suspend then Hibernate** action is included, while normal Suspend and laptop-lid behavior remain unchanged.
- **Idle delay** measures activity to suspend. **Hibernate delay** measures time spent suspended before hibernation.
- The first release uses one idle delay and one hibernate delay, plus **Hibernate while plugged in**, which defaults off rather than introducing fully separate AC and battery profiles.
- If hibernation is unavailable, Hibermachy falls back to ordinary suspend, reports the limitation clearly, and points to `omarchy hibernation setup`.
- Compatibility is tested explicitly against Omarchy 4.0.1, uses documented Quattro contracts, treats later 4.x versions as best-effort until tested, and makes no pre-Quattro or Omarchy 5 promise.

## Comments

Resolved with the user while naming the Wayfinder destination and mapping the breadth-first frontier.
