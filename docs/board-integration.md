# Planned DE10-Nano integration

Target device: Cyclone V SE 5CSEBA6U23I7. The board has one SoC containing the ARM HPS and FPGA fabric. All receive acceptance logic remains in FPGA fabric; HPS is trusted for key/session provisioning and public telemetry.

## CDC and reset

SPI mode 0 is initially limited to 2 Mbit/s. The sampler uses free-running clk_io at 25 MHz instead of SCLK, so CS termination remains observable when the master stops SCLK. Synchronization and board/master setup/hold constraints must be designed and checked before the target link rate is claimed.

The 128x10 DCFIFO transfers byte and SOP/EOP/ABORT tokens into clk_sys at 50 MHz. A sticky overflow flag crosses separately: a full FIFO might prevent enqueueing ABORT. Overflow invalidates the whole frame. Clear requires both-domain flush acknowledgement. Synchronization/Gray-pointer timing constraints and reset recovery/removal come from the selected Cyclone V-compatible IP configuration, then TimeQuest/CDC reports are reviewed. Random-phase simulation alone cannot prove metastability safety.

Asynchronous security reset assertion closes admission; deassertion is synchronized in each domain. The join controller waits for both clocks, FIFO flush, private/shadow scrubbing and new trusted provisioning. A stopped clock prevents cleanup completion and READY remains low. Ascon's vendor reset is synchronous, so internal cleanup requires available clock edges. The tested guard scrubs its 16x32 quarantine in 16 write iterations; this is distinct from physical key erasure guarantees.

## Proposed MMIO map

This map is a proposed specification, not implemented RTL.

| Byte offset | Access | Register |
|---|---|---|
| 0x00 | Write | Control: stage/activate session, security reset |
| 0x04 | Read | Public status: active, busy, locked, scrub/flush done |
| 0x08 | Read | Public error counters/status |
| 0x10..0x1c | Write only | Four 32-bit key words, writable while LOCKED only |
| 0x20..0x24 | Write | Staged 64-bit session ID |
| 0x28 | Write | Staged 32-bit destination |
| 0x30..0x34 | Read | Last committed 64-bit sequence |

Provisioning activates the staged context atomically only after all key words and metadata are present and reset/cleanup is complete. Keys, plaintext, core state, shadow and live-application write ports are absent from the HPS address map. Production key generation must use a trusted CSPRNG; the demonstration fixture is not a production key manager.

The first board demo is LED/state control. Arbitrary actuator integration must use an adapter with shadow and commit semantics; attaching a per-word actuator directly to app_data does not preserve transaction atomicity.
