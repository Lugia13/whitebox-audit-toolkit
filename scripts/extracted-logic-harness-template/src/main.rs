//! Extracted-logic harness template.
//!
//! See docs/05-extracted-logic-harness-pattern.md for the full methodology.
//!
//! Fill in each section below with verbatim logic copied from the real
//! source, replacing only what's unavoidable (hardware I/O, vendor APIs)
//! with minimal mocks that honor the *documented* contract of what they do.

use std::sync::atomic::{AtomicBool, Ordering};

// ---------------------------------------------------------------------
// 1. Verbatim struct/type definitions copied from the real source.
// ---------------------------------------------------------------------
struct Target {
    // exact fields from the real type
}

// ---------------------------------------------------------------------
// 2. Verbatim logic under test, copied exactly from the real source.
//    Do not "clean up" or "simplify" anything here — the whole point is
//    that conclusions drawn from this harness transfer to the real code.
// ---------------------------------------------------------------------
impl Target {
    fn suspect_function(&self, _input: &[u8]) -> bool {
        // paste the real logic here
        unimplemented!("replace with verbatim logic under test")
    }
}

// ---------------------------------------------------------------------
// 3. Minimal mocks for anything unavoidable (hardware, vendor APIs).
//    Mock to the DOCUMENTED contract, not to convenience.
// ---------------------------------------------------------------------
static MOCK_DEPENDENCY_CALLED: AtomicBool = AtomicBool::new(false);

fn mock_dependency() {
    MOCK_DEPENDENCY_CALLED.store(true, Ordering::SeqCst);
}

// ---------------------------------------------------------------------
// 4. Instrumented, falsifiable verdict. The printed output alone should
//    let a reader independently confirm the claim without re-deriving
//    your reasoning.
// ---------------------------------------------------------------------
fn main() {
    let target = Target {};
    let crafted_input: Vec<u8> = vec![]; // the specific adversarial input

    println!("--- Extracted-logic harness ---");
    println!("Input under test: {crafted_input:?}");

    let result = target.suspect_function(&crafted_input);

    println!("Result: {result}");
    println!(
        "Mock dependency invoked: {}",
        MOCK_DEPENDENCY_CALLED.load(Ordering::SeqCst)
    );

    // Replace with the actual claim being tested. A harness that doesn't
    // assert anything isn't proving anything.
    assert!(
        result,
        "expected the invariant under test to hold/break as predicted"
    );

    println!("\nCONFIRMED: behavior matches the predicted claim.");
}
