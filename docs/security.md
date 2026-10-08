# Security model and evidence limits

## Trust and attacker capabilities

The serial path is untrusted. An attacker may observe, modify, replay, truncate, insert and flood frames. The sender's key management, trusted provisioning/HPS, bitstream and application adapter are trusted. One peer, one session and one active frame are assumed. Frames must arrive in increasing sequence order; reordered or delayed older frames are rejected.

Physical probing, side-channel analysis, malicious trusted HPS, compromised senders, tampered bitstreams and adversarial JTAG are outside the present claim. READY/busy admission and timeout limit unfinished transactions but do not guarantee availability.

## Properties evaluated

- No application valid before successful authentication.
- A rejected transaction leaves live application state unchanged.
- An accepted transaction has the expected commit count and payload.
- Backpressure holds approved data and metadata stable.
- Bad-tag high sequence does not poison the replay counter.
- Reset/abort/selected control faults during release do not partially commit.
- Quarantine words are zero after cleanup in tested cases.

Security reset and application power-on reset are distinct. Security reset closes the gate and discards shadow but preserves the last committed live value. Application power-on reset intentionally sets its configured safe initial value. Guard reset clears replay state while revoking the session, so a fresh session key is mandatory before reactivation.

## Evidence boundary

The current snapshot includes 1089 official KAT core-only tests with guard disabled, 1536 main valid transactions, 7936 one-bit mutations on nine basis transactions, and 136 further directed/position/timeout cases. The total core/guard/application campaign is 10697 cases and 1593 expected commits. Mutations cover key, nonce, 32-byte AD, ciphertext and tag on lengths 1/15/16/17/31/32/33/63/64, not every legal frame. Fourteen selected single-bit FSM/token injections remain part of the directed set. Live state and replay-state changes are checked across each clock edge. Seven isolated guard contracts and 10290 separate byte-parser cases add interface evidence; two deliberately broken acceptance implementations must be detected by the regression.

No SPI/CDC, dual-domain reset controller, MMIO key vault, Quartus fitting, hardware metastability, board measurements, physical faults or leakage tests have been completed here. Passing finite simulation tests is not a formal proof, cryptographic certification, penetration-test certification or a claim of commercial readiness.
