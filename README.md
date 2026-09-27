# Hibermachy

Hibermachy adds automatic staged sleep to Omarchy: suspend after an idle delay,
then hibernate after a hibernate delay. Manual staged sleep is also available.
It preserves Omarchy's existing idle, locking, and power behavior.

The first release, **v0.1.0**, is experimental and is being prepared. No stable
release is published yet. See the [release preparation record](verification/v0.1.0-preparation.md)
for completed work and outstanding gates.

Automatic staged sleep honors Stay Awake and idle inhibitors. Manual staged
sleep bypasses those two controls while still honoring system sleep inhibitors.
The panel separates requested system policy, effective system policy, and
operational readiness, and reports the observed lid-close action. Hibermachy
does not configure the laptop lid action or repair platform hibernation support.

The plugin starts disabled. System-policy changes require a separately installed,
root-owned privileged policy helper and interactive administrator authorization.
The helper cannot initiate sleep. Read the [source-package contract](packaging/README.md)
before installation; the development recipe deliberately contains release
checksum and signing-key placeholders and is not an installable release recipe.

Optional hardware workarounds are documented separately:

- [IPTS staged-sleep guard](hardware/iptsd/README.md)
- [Marvell Wi-Fi staged-sleep guard](hardware/mwifiex/README.md)

For development, `npm run test:candidate` runs the ordinary candidate checks.
`npm test` also runs the hosted Quattro matrix and activity/hardware regressions.
The hosted checks require a usable graphical environment and simulate sleep;
physical hibernation verification is a separate attended procedure.
