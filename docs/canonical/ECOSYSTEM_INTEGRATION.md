# Ecosystem Integration — Arbiter

## Canonical service identity

| Field | Value |
|---|---|
| Service ID | `arbiter` |
| Canonical name | Arbiter |
| Ecosystem family | `covenant` |
| Ecosystem layer | `foundation.policy-law` |
| Standalone-first | `true` |

## Role

Deterministic machine law engine: evaluates declarative PolicySets against factual inputs and returns cryptographically attestable allow/deny/quarantine decisions (arbiter.v1, first match wins, default deny). Pure evaluation with no side effects; sits above Packet Constitution v1 transport integrity.

## This service owns

- Pure, side-effect-free evaluation of declarative PolicySets
- PolicySet, PolicyInput, and PolicyDecision v1 schemas
- Attestable decision hashes (SHA-256 over canonical JSON)

## This service does not own

- Policy enforcement and the governance interface (covenant-gate)
- Monitoring and recording of policy decisions (lawvm)
- Transport and packet integrity (Packet Constitution v1)
- Executing the permitted behavior (engines)

## Upstream services

- None

## Downstream consumers or operators

- None

## Contract families

- `policy.policyset.*`
- `policy.input.*`
- `policy.decision.*`

## Integration rules

1. This repository must remain independently understandable, testable, buildable, and releasable.
2. Ecosystem integrations extend capability but do not replace standalone correctness.
3. Integrations use explicit, versioned schemas and receipts.
4. No undocumented database sharing, hidden filesystem coupling, or implicit trust is permitted.
5. Producer claims must be independently verified by the receiving boundary where verification is required.
6. Integration failure must not silently corrupt local authoritative state.
7. Missing upstream services must produce an explicit unavailable, unknown, deferred, or failed state according to the local contract.
8. This repository's current implementation must not be treated as the complete product definition.

## Authoritative ecosystem sources

- `../Constellation/ecosystem/SERVICE_MAP.md`
- `../Constellation/registry/services.json`
- `../Constellation/ecosystem/AGENT_POLICY.md`
- `../Constellation/ecosystem/SHARED_INVARIANTS.md`

## Change governance

Changes to this service's ecosystem role, ownership boundaries, upstream dependencies, or downstream responsibilities require:

1. A proposal under `docs\proposals`.
2. A documented compatibility impact.
3. Updated registry entries in Constellation (`registry/services.json`) and a re-published service map.
4. Updated positive and negative integration tests.
5. A new Constellation doctor receipt.
