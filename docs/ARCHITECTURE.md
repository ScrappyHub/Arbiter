# Arbiter Architecture (v1)

## Layer placement
- BELOW: application logic (UI, engines)
- ABOVE: transport validity (Packet Constitution v1 handles byte-level correctness)

Arbiter assumes artifacts/packets are already transport-valid.

## Inputs and outputs
- Inputs: PolicySet + PolicyInput
- Output: PolicyDecision

Arbiter itself does not mutate artifacts or packets.

## Determinism
Arbiter is pure evaluation:
- it never reads wall-clock time (only env.now from input)
- it never performs IO side effects as part of evaluation
- it produces the same decision for the same inputs and policy bytes

## Integration points
- WatchTower: call Arbiter after transport verify, before ingest routing
- Covenant Gate: call Arbiter to decide allow/deny/quarantine before enforcement
- CORE/TRIAD: call Arbiter to validate claims before sealing/witnessing
