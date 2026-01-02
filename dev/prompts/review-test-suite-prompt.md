# Thoroughly Review Test Suite

Carefully examine the test suite. Report and fix:

- duplicate tests testing the same thing
- tests that test the test setup rather than the actual production code
- verbose tests, e.g.:
  - multiple calls to `to include` that should be compressed into a single call with a comma separated string list
  - duplicate test code that can be made more concise by the use of arrays of test data with an `.each`, etc. block
- complex tests that could be clarified with comments, intermediate variables, extracted methods, etc.

Ensure that any code changes comply with rubocop linting:

- run `rubocop` to see if there are any errors
- run `rubocop -A` to fix anything rubocop is capable of fixing
- fix the other errors yourself

Run the test suite as necessary to verify that all tests pass.
