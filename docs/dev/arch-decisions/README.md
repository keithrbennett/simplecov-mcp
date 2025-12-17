# Architecture Decision Records

[Back to main README](../../README.md) | [Architecture Overview](../ARCHITECTURE.md)

## What is an ADR?

An Architecture Decision Record (ADR) captures a significant architectural decision made during the development of this project, along with its context and consequences.

## ADR Format

Each ADR follows this structure:

### Title
A short phrase describing the decision (e.g., "Dual-Mode Operation: CLI and MCP Server")

### Status
- **Accepted**: The decision has been made and is currently in effect
- **Proposed**: Under consideration
- **Deprecated**: No longer applicable
- **Superseded**: Replaced by a newer decision

### Context
The background, problem statement, and constraints that led to the decision.

### Decision
The architectural choice that was made.

### Consequences
The implications of this decision, both positive and negative. This includes:
- Benefits gained
- Trade-offs accepted
- Complexity introduced
- Future constraints

### References
Links to related code, issues, documentation, or other ADRs.

## Index of ADRs

- [001: Dual-Mode Operation](001-x-arch-decision.md) - CLI vs MCP server mode detection
- [002: Context-Aware Error Handling](002-x-arch-decision.md) - Mode-specific error handling strategy
- [003: Coverage Staleness Detection](003-x-arch-decision.md) - Three-type staleness system
- [004: Ruby Instance Eval for Success Predicates](004-x-arch-decision.md) - Dynamic Ruby evaluation approach
- [005: No SimpleCov Runtime Dependency](005-x-arch-decision.md) - Superseded by the multi-suite merge work (runtime SimpleCov dependency)

## When to Create an ADR

Create an ADR when:
- Making a decision that affects the structure or behavior of the system
- Choosing between multiple viable approaches
- Accepting significant trade-offs
- Making decisions that future maintainers should understand

## Contributing

When adding a new ADR:
1. Use the next sequential number (e.g., `006-x-arch-decision.md`)
2. Follow the format outlined above
3. Update this README's index
4. Link to relevant code and documentation
