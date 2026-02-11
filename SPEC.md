# Arbiter Specification v1

## 0. Identity (LOCKED)
- Layer name: Arbiter
- Engine ID: arbiter.v1
- Role: deterministic policy evaluation (machine-law judgment)
- NOT an enforcer, NOT a mutator, NOT a watcher

## 1. Objects (LOCKED)
- policy.policyset.v1
- policy.rule_file.v1
- policy.rule.v1
- policy.input.v1
- policy.decision.v1

All MUST validate against schemas in /schemas.

## 2. Canonical bytes + hashing (LOCKED)
Arbiter hashes canonical JSON bytes:
- UTF-8, no BOM
- LF newlines
- canonical JSON:
  - object keys sorted lexicographically
  - arrays preserved in order
  - no insignificant whitespace
  - stable escaping
  - stable number rendering

Hash algorithm: SHA-256, lowercase hex, prefixed: `sha256:`.

## 3. Evaluation contract (LOCKED)

### 3.1 Validation
Evaluator MUST:
- validate policyset.json against policyset.schema.json
- load each rule file listed in policyset.rule_files[]
- validate each rule file against rule_file.schema.json
- validate each rule against rule.schema.json
- validate input against input.schema.json

### 3.2 Rule ordering (LOCKED)
Rules are evaluated in this stable order:
1) rule files in the exact order listed in policyset.rule_files[]
2) within each rule file: rules sorted by rule.id lexicographically (ascending)

### 3.3 Match semantics (LOCKED)
Evaluation mode is FIRST_MATCH_WINS:
- the first rule whose `when` evaluates to true determines:
  - decision (effect)
  - reasons
  - obligations

If no rule matches:
- decision MUST be `deny`
- reasons MUST include `DENY_NO_RULE_MATCHED`
- matched_rule_id MUST be null

### 3.4 Condition language (LOCKED op set v1)
Conditions are JSON objects with exactly one operator key.

Composition:
- all: [{cond},{cond},...]
- any: [{cond},{cond},...]
- not: {cond}

Predicates (operands are either literals or pointer strings like `$.artifact.namespace`):
- exists: "$.path.to.value"
- eq / neq
- lt / lte / gt / gte
- in (value IN array)
- contains (array CONTAINS value)

Time:
- lt_days: [created_at, env.now, N]
- gte_days: [created_at, env.now, N]
Timestamps MUST be RFC3339 strings. Arbiter MUST use env.now (no wall-clock).

Missing operands:
- exists returns false if missing
- all other operators return false when any required operand is missing

### 3.5 Outputs + hashes (LOCKED)
Arbiter MUST produce a policy.decision.v1 with:
- decision
- reasons (codes only; no prose required)
- obligations (data only)
- policy_hash
- input_hash
- decision_hash
- matched_rule_id (string or null)
- evaluated_at (from input.env.now or provided evaluation time, but MUST be deterministic per caller contract)

Hash requirements:
- input_hash = sha256(canonical_bytes(input))
- policy_hash = sha256(canonical_bytes(policyset + ordered rule docs))
- decision_hash = sha256(canonical_bytes(decision with signature omitted/absent))

## 4. Reason codes (LOCKED)
Reasons are stable codes such as:
- OK_TRUSTED_NAMESPACE
- DENY_NAMESPACE_NOT_ALLOWED
- QUARANTINE_TOO_OLD
- DENY_NO_RULE_MATCHED

Reason codes MUST be machine-consumable; prose is non-normative UI text outside Arbiter.

## 5. Obligations (LOCKED)
Obligations are data-only task descriptors (type + params).
They MUST NOT embed executable code.

## 6. Compatibility
Any change to semantics MUST increment schema versions (v2+).
