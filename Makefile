.PHONY: verify snapshot mutations capture lint demo
verify:
	bash verification/run.sh
snapshot:
	python3 scripts/check_snapshot.py
mutations:
	python3 scripts/mutation_check.py
capture:
	python3 scripts/capture_evidence.py
lint:
	verilator --lint-only --timing -Wno-fatal -Iverification/vendor/ascon-rtl --top-module tb_sentinel verification/tb_sentinel.sv verification/sentinel_guard.sv verification/sentinel_app.sv
	verilator --lint-only --timing -Wno-fatal --top-module tb_frame_parser verification/tb_frame_parser.sv rtl/sentinel_frame_parser.sv
demo:
	python3 scripts/show_demo.py
