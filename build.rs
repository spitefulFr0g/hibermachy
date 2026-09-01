fn main() {
    let default_root = format!("{}/target/hibermachy-policy-helper-test", std::env::var("CARGO_MANIFEST_DIR").expect("cargo sets manifest directory"));
    let root = std::env::var("HIBERMACHY_TEST_ROOT").unwrap_or(default_root);
    if std::env::var_os("CARGO_FEATURE_TEST_SUPPORT").is_some() {
        println!("cargo:rustc-cfg=hibermachy_test_root");
        println!("cargo:rustc-env=HIBERMACHY_COMPILED_ROOT={root}");
    }
    println!("cargo::rustc-check-cfg=cfg(hibermachy_test_root)");
}
