# Arbiter

Deterministic Machine Law Engine.

Arbiter evaluates declarative PolicySets against factual inputs and produces cryptographically attestable decisions.

It is the canonical “law layer” of the ecosystem.

---

## Responsibility

Input:
- PolicySet (`policy.policyset.v1`)
- PolicyInput (`policy.input.v1`)

Output:
- PolicyDecision (`policy.decision.v1`)

Decision ∈ { allow, deny, quarantine }

---

## Locked invariants (v1)

- Engine ID: `arbiter.v1`
- Evaluation mode: `FIRST_MATCH_WINS`
- If no rule matches: `deny` with reason `DENY_NO_RULE_MATCHED`
- Rule files are schema’d objects: `policy.rule_file.v1`
- Policies contain no procedural logic (data only)
- Evaluation is pure (no side effects)
- Hashing is SHA-256 over canonical JSON bytes

---

## Relationship to Packet Constitution v1

- Packet Constitution v1 defines transport physics (bytes, hashes, PacketId, finalization order, non-mutation verification).
- Arbiter defines law (allow/deny/quarantine) above transport validity.

Flow:
1) Verify packet integrity via Packet Constitution v1
2) Evaluate permission via Arbiter
3) Engines execute behavior

---
