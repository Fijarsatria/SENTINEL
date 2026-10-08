# Team preparation and bootcamp

Team TRINITY LFA: FIJAR SATRIA PINANDITA MANGKAUNA (lead), LUTFI GHIFFARI HIBAN, ABDUL JABBAR HAWALI AL DZAHABI, Telkom University. The teaching supervisor remains to be confirmed in the proposal.

| Owner | Main responsibility | Cross-review |
|---|---|---|
| Lead | Protocol, threat model, C/Python oracle, scoreboard and demo | Guard acceptance and claims |
| Member 1 | Ascon adapter, guard, trusted provisioning, shadow/commit | Endianness and reset behavior |
| Member 2 | SPI, CDC, Quartus/TimeQuest, board measurement | Framing, stalls and CDC constraints |

## Preparation 9-17 October 2026

9-10: sequential RTL, FSM, reset and ready/valid; each member explains one full waveform transaction. 11-12: rerun evidence, check standardized KAT and protocol byte order. 13-14: SPI parser, FIFO tokens, context freeze and overflow tests. 15-17: board setup, modular integration, mentor review and dry run. These are planned deliverables, not completed claims.

## Bootcamp 18-20 October 2026

| Day | Morning | Afternoon | Exit evidence |
|---|---|---|---|
| 18 October | Bring-up board, clocks and first known-good serial transaction | Integrate frame/CDC/adapter and commit-visible LED | Bitstream and trace for one accepted packet, no partial writes |
| 19 October | Tamper/replay/truncation/stall/reset tests with Python scoreboard | Fault campaign, cleanup validation and mentor fixes | Logs for accepted and rejected transactions; zero unauthorized commit in tested set |
| 20 October | Fitting/timing/resource and comparable baseline measurements | Freeze release, record 3-5 minute demo and rehearse | Actual report, tagged source, reproducible demo and honest remaining limits |

If serial/board integration misses an exit criterion, the team reports the actual completed scope and continues to show the reproducible core/guard/application simulation. A planned test is never relabeled as a completed result.

## Learning order and sources

1. Registers, combinational/sequential logic, FSM, reset, then ready/valid: read vendor core and `tb_sentinel.sv` beside the waveform.
2. AEAD, nonce uniqueness and AD: https://csrc.nist.gov/pubs/sp/800/232/final and https://www.rfc-editor.org/rfc/rfc5116
3. Core interface, mode and stalls: https://github.com/rprimas/ascon-verilog
4. Board setup: https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=165&Language=English&No=1046&PartNo=2
5. FIFO/reset/constraints: https://docs.altera.com/r/docs/683522/current

All members must explain why a valid tag is insufficient for replay acceptance, how private and shadow buffers differ, and why last_seq advances only at commit.
