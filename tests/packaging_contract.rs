use std::{fs, path::Path};

fn packaging_file(name: &str) -> String {
    fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("packaging")
            .join(name),
    )
    .unwrap_or_else(|error| panic!("missing packaging/{name}: {error}"))
}

#[test]
fn package_manifest_is_source_verified_and_does_not_invent_release_identity() {
    let package = packaging_file("PKGBUILD");

    assert!(package.contains("source=("));
    assert!(package.contains("hibermachy-helper-${pkgver}.tar.gz::"));
    assert!(package.contains("hibermachy-helper-${pkgver}.tar.gz.sig"));
    assert!(package.contains("sha512sums=('__RELEASE_SHA512__' '__RELEASE_SIGNATURE_SHA512__')"));
    assert!(package.contains("validpgpkeys=('__RELEASE_SIGNING_KEY__')"));
    assert!(package.contains("__RELEASE_SIGNATURE_SHA512__"));
    assert!(!package.contains("SKIP"));
    assert!(package.contains("cargo build --release --locked"));
}

#[test]
fn package_metadata_uses_the_canonical_repository_and_valid_srcinfo_indentation() {
    let package = packaging_file("PKGBUILD");
    let srcinfo = packaging_file(".SRCINFO");
    let repository = "https://github.com/spitefulFr0g/hibermachy";

    assert!(package.contains(&format!("url='{repository}'")));
    assert!(package.contains(&format!("{repository}/releases/download/v${{pkgver}}/")));
    assert!(srcinfo.contains(&format!("\turl = {repository}")));
    assert!(srcinfo.contains(&format!(
        "\tsource = hibermachy-helper-0.1.0.tar.gz::{repository}/releases/download/v0.1.0/"
    )));
    assert!(!package.contains("github.com/hibermachy/hibermachy"));
    assert!(!srcinfo.contains("github.com/hibermachy/hibermachy"));
    assert!(!srcinfo.contains("\\t"));
    assert!(srcinfo.lines().skip(1).all(|line| {
        line.starts_with('\t') || line.starts_with("pkgname = ") || line.is_empty()
    }));
}

#[test]
fn package_installs_only_root_owned_helper_and_polkit_declaration() {
    let package = packaging_file("PKGBUILD");

    assert!(package.contains("/usr/libexec/hibermachy-policy-helper"));
    assert!(package.contains("/usr/share/polkit-1/actions/org.hibermachy.policy-helper.policy"));
    assert!(package.contains("install -Dm755"));
    assert!(package.contains("install -Dm644"));
    assert!(!package.contains("systemctl"));
    assert!(!package.contains("sleep.conf.d/90-hibermachy.conf"));
}

#[test]
fn polkit_requires_fresh_administrator_authentication_for_the_helper() {
    let policy = packaging_file("org.hibermachy.policy-helper.policy");

    assert!(policy.contains("<allow_any>no</allow_any>"));
    assert!(policy.contains("<allow_inactive>no</allow_inactive>"));
    assert!(policy.contains("<allow_active>auth_admin</allow_active>"));
    assert!(policy.contains("org.freedesktop.policykit.exec.path"));
    assert!(policy.contains("/usr/libexec/hibermachy-policy-helper"));
    assert!(!policy.contains("auth_admin_keep"));
    assert!(!policy.contains("yes</allow_"));
}

#[test]
fn package_removal_repeats_narrow_reset_without_claiming_removal_failed() {
    let install = packaging_file("hibermachy-helper.install");

    assert!(install.contains("pre_remove()"));
    assert!(install.contains("hibermachy-policy-helper reset"));
    assert!(install.contains("|| :"));
    assert!(!install.contains("rm -rf"));
}
