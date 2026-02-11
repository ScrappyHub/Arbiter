# Arbiter Integration (v1)

## Contract
1) Verify transport integrity using Packet Constitution v1
2) Construct PolicyInput:
   - env.now, env.mode
   - artifact.namespace, signer.key_id, created_at (if known)
   - trust.allowed_namespaces / allowed_key_ids / allowed_principals (resolved by the caller)
3) Evaluate:
   - PolicySet references rule files (policy.rule_file.v1)
4) Consume PolicyDecision:
   - allow -> proceed
   - deny -> reject
   - quarantine -> route to quarantine + obligations

## Locked defaults
- FIRST_MATCH_WINS
- deny if no match

## Responsibility boundaries
- Arbiter does not resolve trust bundles.
- Arbiter consumes trust facts in the PolicyInput.
- Arbiter does not “self-heal” artifacts.
- Arbiter outputs deterministic reason codes and obligations.
