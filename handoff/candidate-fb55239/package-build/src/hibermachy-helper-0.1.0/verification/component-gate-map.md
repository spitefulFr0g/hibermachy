# Component-to-gate mapping

Uncertain impact selects the broader gate set. No shipped component is exempt
because it is small, generated, or documentation-shaped.

| Component or artifact | Product | Helper | Lifecycle | Static/packaging | Cross-seam | Candidate/hardware |
| --- | --- | --- | --- | --- | --- | --- |
| `plugin/Service.qml` | required | n/a | n/a | QML | required | required |
| `plugin/Panel.qml`, `plugin/AccessibleConfirmDialog.qml` | required | n/a | menu adapter | QML/accessibility | required | required |
| `plugin/manifest.json`, `plugin/Panel.qml` menu adapters | required | n/a | required | generated consistency | required | required |
| `src/*.rs`, `build.rs` | n/a | required | n/a | Rust/static | required | required |
| `lifecycle/*` | n/a | n/a | required | shell/static | required | required |
| `packaging/*` | n/a | required | required | package validation | required | candidate |
| `tests/*.rs`, `tests/*.sh` | required | required | required | shell/Rust/fixture lint | required | required |
| `tests/fixtures/**` | required | required | required | fixture validation | required | candidate |
| `verification/*.md` | traceability | gate contract | gate contract | generated consistency | required | release evidence |
| `Cargo.toml`, `Cargo.lock`, `package.json` | build contract | build contract | test contract | dependency/static | required | candidate |
| release records and checksums | evidence | evidence | evidence | supply chain | required | candidate/hardware |
