## Qualification closed — 2026-09-20

Successor candidate `625d5a22c57d7ab0f792330a3bb7eaa0880f7304` supersedes `2bb7cb3`, which three defects invalidated.

**This issue is being closed with three criteria unsatisfied.** They are resolved
by recorded owner determination, not by evidence. Each has a version-controlled
determination document under `verification/`.

| AC | Subject | Outcome |
| --- | --- | --- |
| 1 | Candidate identity | Satisfied — archive reproducible and tree-identical |
| 2 | Clean environment journeys | **Accepted unmet** — no clean environment exists |
| 3 | Hostile privileged tests | Satisfied except real Polkit and real package manager |
| 4 | Lifecycle journeys | Satisfied — nine journeys with scope inventories |
| 5 | Accessibility sign-off | **Accepted unmet** — assistive tech removed from scope |
| 6 | Supply chain | Satisfied — zero dependencies, zero advisories |
| 7 | Independent review | **Met by owner determination** — agent, not human |
| 8 | Sanitized evidence | Satisfied |

### Defects fixed since `2bb7cb3`

1. Lifecycle status reported `mismatched` after a legitimate plugin removal that
   left the helper installed, with guidance telling the operator to install an
   overlapping helper. Now reports `incomplete`.
2. The requested-versus-effective policy comparison carried no announcement
   handler, so the change was never conveyed non-visually.
3. All three announcement handlers gated on a stale `visible` binding. The first
   action result after an empty state was never announced, and clearing the
   result announced an empty string.

Each has regression coverage demonstrated failing before the fix and passing
after.

### What is explicitly not claimed

- No clean-room qualification. The rootless namespace battery is a substitute and
  is never described as clean-room.
- No accessibility sign-off. Keyboard-only navigation is unevidenced; screen
  reader behaviour is out of scope. The panel must not be described as accessible.
- No human security review. No security certification is claimed.
- No hardware verification — that remains #26.
- Real Polkit authorization/cancellation/denial and real package install/remove
  were NOT RUN on the current platform.

### Platform note

The only real Polkit and package-manager evidence this project holds was taken on
Omarchy 4.0.3-1; the host is now 4.0.4-1. That evidence is not re-claimed as
current.

### Identity

```
commit     625d5a22c57d7ab0f792330a3bb7eaa0880f7304
tree       8f3e33a03b1609d2957c63367a4a9c471b6e4ef6
archive    1eb0a56ca3cff03012884ef7cb7e8dc0c659b8b8db4ccf39d52a0fb75b3a9e5f
signature  0327309429e43375b02a029efeee7ab5cfbf5242ff0205c03715872769b0e94a
package    4f5134c7696c787e9c6c7033ff98c0d55cb853b20be5d536ca74d4464a118604
binary     be889db04d2d4f7730d329e38c7886bddb967d1866293ba304a0e0a90568c22a
recipe     git archive --format=tar --prefix=hibermachy-helper-0.1.0/ <commit> | gzip -n -9
key        0B1C5414F8D18F8B6AA78957335FEBC82DB247EC
```

The archive is signed and the signature verifies against the recorded
fingerprint. The package built unprivileged with makepkg SHA-512 and GPG source
verification both passing. It contains exactly two payload files, root-owned,
binary `0755` and non-setuid, polkit action `0644` with
`allow_any=no allow_inactive=no allow_active=auth_admin`. The binary is a
stripped PIE with full RELRO, `BIND_NOW` and a non-executable stack, and the
`test-support` feature is absent.

**The installed helper binary is byte-identical to the predecessor's**
(`be889db0…`). The defect fixes touched the lifecycle script and the QML panel,
not the helper source. This was confirmed by rebuilding and comparing rather
than assumed, so the AC3 hostile battery and the AC7 helper review carry forward
to this candidate.

Known observation, unchanged from the predecessor: `gdb-add-index` reported no
debugging symbols for the stripped binary. That is the host debug-package
default, not a packaging fault. The recorded build used the rustup-managed
toolchain rather than the distribution `rust` package the recipe declares;
versions match exactly (cargo/rustc 1.98.1), so this is a provenance gap, not a
version mismatch.

`main` must be **fast-forwarded** to this commit. A merge commit is a different
candidate under AC1 and would invalidate everything above.
