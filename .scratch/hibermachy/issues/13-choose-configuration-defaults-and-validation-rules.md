# Choose configuration defaults and validation rules

Type: grilling
Status: resolved
Blocked by: 08

## Question

What versioned schemas, first-run defaults, accepted ranges, units, cross-field constraints, invalid-value behavior, and migration rules govern Hibermachy's user policy and root-owned system policy?

## Answer

Hibermachy has one custom versioned schema: the user-policy document at
`$XDG_CONFIG_HOME/hibermachy/config.json`. Version 1 is a UTF-8 JSON object with
no byte-order mark, a maximum encoded size of 16 KiB, exactly these four keys,
and these initial values:

```json
{
  "schemaVersion": 1,
  "revision": 1,
  "automaticPolicyEnabled": false,
  "idleDelaySeconds": 1800
}
```

All fields are required. `schemaVersion` is exactly `1`;
`automaticPolicyEnabled` is a JSON boolean; `idleDelaySeconds` is an integer
from 300 through 86,400 inclusive; and `revision` is a service-owned integer
from 1 through JavaScript's maximum safe integer inclusive. Unknown, duplicate,
missing, mistyped, fractional, unsafe, or out-of-range values invalidate the
whole document. The canonical writer uses the displayed key order and
indentation and terminates the file with one newline. Persisted time values use
whole seconds; the interface may display friendlier units but normalizes them
before mutation.

Whenever the service loads an absent document, including first activation, it
atomically creates the safe defaults above. Automatic staged sleep stays
disarmed until that write commits. Removing the document therefore resets user
intent to disabled rather than recovering hidden prior values. A manual staged-
sleep request never creates user configuration or applies privileged policy as
a side effect.

The first-run system-policy proposal is a 7,200-second hibernate delay with
hibernation on AC disabled. It is a product default presented by the settings
interface, not a duplicate persisted authority. Requested system policy does
not exist until the user explicitly authenticates an apply. Automatic-policy
enablement may be saved before then, preserving intent, but automatic execution
stays disarmed until the owned requested policy is valid and both effective
system-policy values can be read. Applying or discovering a ready policy still
requires fresh user activity before automatic execution re-arms.

The helper continues to expose the fixed `apply <delay-seconds> <yes|no>` and
`reset` commands. The delay argument is canonical unsigned decimal and must be
from 900 through 604,800 seconds inclusive; the AC argument is exactly `yes` or
`no`. An apply always supplies both values as one validated pair and emits:

```ini
# Managed by Hibermachy; format-version=1
[Sleep]
HibernateDelaySec=<integer>s
HibernateOnACPower=<yes|no>
```

The generated drop-in is standard systemd configuration, not a second custom
data schema. Its format comment identifies generated content for readback and
future replacement. Upgrades do not rewrite it automatically; the next
authenticated apply emits the current canonical format.

Idle delay and hibernate delay have no ordering constraint because they are
sequential periods. Enabling automation also does not require hibernation to be
currently executable: Hibermachy preserves that intent and uses the already-
specified suspend fallback. A malformed or incomplete owned drop-in, or an
unreadable or incomplete effective policy, disarms automatic execution without
disabling the manual action.

A complete, parseable administrator override remains authoritative even when
its effective delay falls outside the helper's accepted range. Hibermachy
reports the requested/effective mismatch and its provenance but neither fights
the override nor calls valid administrator policy invalid. This includes an
effective delay as short as one second. Manual staged sleep remains subject to
the existing capability and inhibitor checks in every configuration state.

The service increments `revision` only after a successful durable mutation. A
valid external semantic edit observed while the service is running must retain
the current revision; the service then validates and canonicalizes it as a new
mutation and advances the revision. A different observed revision is a conflict
and disarms automation until correction or explicit reset. On service startup,
any otherwise-valid safe revision is accepted because no pre-reload client can
remain live. Revision exhaustion rejects mutation and leaves the document
untouched. Formatting-only external changes may be canonicalized without
advancing the revision.

Invalid existing documents and newer schemas remain untouched. Hibermachy
disarms automatic execution, reports a precise field or document error, and
offers explicit reset; it never silently repairs the file, guesses defaults, or
runs from a hidden last-known-good copy. Reset writes the safe disabled policy,
using the next revision when a valid current revision is known and revision 1
otherwise.

Version 1 accepts no unversioned legacy format. Future releases may migrate only
explicitly recognized older user schemas through sequential migrations. The
complete result is validated and atomically committed, advancing the revision
once. Failure leaves the original untouched and automation disarmed. A
migration may preserve existing enablement but must never enable automation,
change established user intent, or apply privileged policy merely to populate a
new field. Unknown and newer schemas never migrate automatically.

## Comments

Resolved with the user through three decision rounds plus a final shared-
understanding confirmation. The user accepted every recommendation after
clarifying that first run means the service's first load after installation and
activation, not the first manual staged-sleep request.
