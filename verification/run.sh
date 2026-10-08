#!/usr/bin/env bash
set -euo pipefail
SENTINEL_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$SENTINEL_ROOT"
SENTINEL_PYTHON=${SENTINEL_PYTHON:-python3}
SENTINEL_VERILATOR=${SENTINEL_VERILATOR:-verilator}
command -v gcc >/dev/null
command -v g++ >/dev/null
command -v make >/dev/null
"$SENTINEL_VERILATOR" --version
"$SENTINEL_VERILATOR" --version > tool_versions.txt
gcc -shared -fPIC -O2 -I vendor/ascon-c-ref vendor/ascon-c-ref/aead.c -o ascon_ref.so
"$SENTINEL_PYTHON" generate_vectors.py
"$SENTINEL_VERILATOR" --binary --timing --trace -Wno-fatal \
  -Ivendor/ascon-rtl --top-module tb_sentinel --Mdir build \
  tb_sentinel.sv sentinel_guard.sv sentinel_app.sv >build.log 2>&1
./build/Vtb_sentinel +VECTORS=vectors.txt +RESULTS=results.csv >simulation.log 2>&1
./build/Vtb_sentinel +VECTORS=demo_vectors.txt +RESULTS=demo_results.csv +WAVES >demo.log 2>&1
"$SENTINEL_PYTHON" summarize_results.py
"$SENTINEL_VERILATOR" --binary --timing -Wno-fatal --top-module tb_frame_parser \
  --Mdir build_parser tb_frame_parser.sv ../rtl/sentinel_frame_parser.sv >parser_build.log 2>&1
./build_parser/Vtb_frame_parser >parser.log 2>&1
"$SENTINEL_VERILATOR" --binary --timing -Wno-fatal --top-module tb_guard_contract \
  --Mdir build_contract tb_guard_contract.sv sentinel_guard.sv >contract_build.log 2>&1
./build_contract/Vtb_guard_contract >guard_contract.log 2>&1
cat simulation.log
cat demo.log
cat parser.log
cat guard_contract.log
