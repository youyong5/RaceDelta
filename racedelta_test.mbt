// Blackbox tests run against the package's public API. Use `@racedelta` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "project scaffold" {
  assert_eq(1 + 1, 2)
}
