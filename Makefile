# ==============================================================================
# RM32 RISC-V RV32I Processor Core - Verification & Build Automation Makefile
# ==============================================================================

SHELL := /bin/bash
export PATH := /opt/homebrew/bin:$(PATH)

IVERILOG := iverilog
VVP      := vvp
VERILATOR:= verilator
YOSYS    := yosys
PYTHON   := python3

RTL_SRCS       := $(wildcard rtl/*.sv)
PIPE_SRCS      := $(wildcard pipelined/*.sv)
UNIT_TESTS     := tests/unit/tb_alu.sv tests/unit/tb_reg_file.sv tests/unit/tb_signextn.sv tests/unit/tb_controller.sv tests/unit/tb_dmem.sv
ASM_SRCS       := $(wildcard tests/asm/*.s)
HEX_FILES      := $(ASM_SRCS:.s=.hex)

.PHONY: all test test-unit test-integration test-pipeline test-iss lint synth wave clean asm

all: lint test

# ------------------------------------------------------------------------------
# Assembly Generation
# ------------------------------------------------------------------------------
asm: $(HEX_FILES)

tests/asm/%.hex: tests/asm/%.s tools/assembler.py
	$(PYTHON) tools/assembler.py $< $@

# ------------------------------------------------------------------------------
# Linting (Verilator -Wall --lint-only)
# ------------------------------------------------------------------------------
lint:
	@echo "=== Linting Single-Cycle Core ==="
	$(VERILATOR) --lint-only -Wall -Irtl --top-module datapath $(RTL_SRCS)
	@echo "=== Linting 5-Stage Pipelined Core ==="
	$(VERILATOR) --lint-only -Wall -Irtl -Ipipelined --top-module pipe_datapath $(RTL_SRCS) $(PIPE_SRCS)
	@echo ">>> Verilator Lint Clean (0 warnings, 0 errors) <<<"

# ------------------------------------------------------------------------------
# Test Execution
# ------------------------------------------------------------------------------
test: asm test-unit test-integration test-pipeline test-iss test-random
	@echo "======================================================================"
	@echo ">>> ALL VERIFICATION SUITES COMPLETED SUCCESSFULLY (100% PASS) <<<"
	@echo "======================================================================"

test-unit:
	@echo "=== Running Unit Testbenches ==="
	@mkdir -p build
	$(IVERILOG) -g2012 -o build/sim_alu rtl/alu.sv tests/unit/tb_alu.sv && $(VVP) build/sim_alu
	$(IVERILOG) -g2012 -o build/sim_rf rtl/reg_file.sv tests/unit/tb_reg_file.sv && $(VVP) build/sim_rf
	$(IVERILOG) -g2012 -o build/sim_signextn rtl/signextn.sv tests/unit/tb_signextn.sv && $(VVP) build/sim_signextn
	$(IVERILOG) -g2012 -o build/sim_ctrl rtl/controller.sv tests/unit/tb_controller.sv && $(VVP) build/sim_ctrl
	$(IVERILOG) -g2012 -o build/sim_dmem rtl/dmem.sv tests/unit/tb_dmem.sv && $(VVP) build/sim_dmem
	@echo ">>> All Unit Tests Passed <<<"

test-integration: asm
	@echo "=== Running Single-Cycle Integration Tests ==="
	@mkdir -p build
	$(IVERILOG) -g2012 -Irtl -o build/sim_edge $(RTL_SRCS) tests/integration/tb_instruction_classes.sv && $(VVP) build/sim_edge
	$(IVERILOG) -g2012 -Irtl -DTEST_HEX='"tests/asm/sum10.hex"' -DTRACE_FILE='"build/trace_sum10_rtl.txt"' -o build/sim_sum $(RTL_SRCS) tests/integration/tb_programs.sv && $(VVP) build/sim_sum
	$(IVERILOG) -g2012 -Irtl -DTEST_HEX='"tests/asm/mem_loop.hex"' -DTRACE_FILE='"build/trace_mem_rtl.txt"' -o build/sim_mem $(RTL_SRCS) tests/integration/tb_programs.sv && $(VVP) build/sim_mem
	@echo ">>> All Single-Cycle Integration Tests Passed <<<"

test-pipeline: asm
	@echo "=== Running 5-Stage Pipeline Integration Tests ==="
	@mkdir -p build
	$(IVERILOG) -g2012 -Irtl -Ipipelined -o build/sim_pipe_haz $(RTL_SRCS) $(PIPE_SRCS) tests/pipelined/tb_pipeline_hazards.sv && $(VVP) build/sim_pipe_haz
	$(IVERILOG) -g2012 -Irtl -Ipipelined -DTEST_HEX='"tests/asm/sum10.hex"' -o build/sim_pipe_sum $(RTL_SRCS) $(PIPE_SRCS) tests/pipelined/tb_pipeline_programs.sv && $(VVP) build/sim_pipe_sum
	$(IVERILOG) -g2012 -Irtl -Ipipelined -DTEST_HEX='"tests/asm/mem_loop.hex"' -o build/sim_pipe_mem $(RTL_SRCS) $(PIPE_SRCS) tests/pipelined/tb_pipeline_programs.sv && $(VVP) build/sim_pipe_mem
	@echo ">>> All 5-Stage Pipeline Tests Passed <<<"

test-iss: asm test-integration
	@echo "=== Running Golden Model ISS Trace-Diff Comparisons ==="
	PYTHONPATH=tools $(PYTHON) tools/run_trace_diff.py build/trace_sum10_rtl.txt tests/asm/sum10.hex
	PYTHONPATH=tools $(PYTHON) tools/run_trace_diff.py build/trace_mem_rtl.txt tests/asm/mem_loop.hex
	@echo ">>> Golden Model Trace Diff Comparisons Match 100% <<<"

test-random:
	@echo "=== Running Random Differential Test (Single-Cycle & 5-Stage vs ISS Golden Model) ==="
	$(PYTHON) tools/random_diff_test.py 600
	@echo ">>> Random Differential Tests Passed (0 mismatches across 600 programs) <<<"

# ------------------------------------------------------------------------------
# Synthesis Check (Generic Yosys Synthesis)
# ------------------------------------------------------------------------------
synth:
	@echo "=== Running Generic Yosys Synthesis Check ==="
	@mkdir -p synth
	$(YOSYS) -p "read_verilog -sv -DSYNTHESIS rtl/*.sv; synth -top datapath -flatten; stat; ltp" > synth/single_cycle_synth.log
	$(YOSYS) -p "read_verilog -sv -DSYNTHESIS rtl/*.sv pipelined/*.sv; synth -top pipe_datapath -flatten; stat; ltp" > synth/pipeline_synth.log
	@echo "Single-cycle cell stats:"
	@grep -A 10 "=== datapath ===" synth/single_cycle_synth.log
	@echo "Pipelined cell stats:"
	@grep -A 10 "=== pipe_datapath ===" synth/pipeline_synth.log
	@echo ">>> Generic Synthesis Complete <<<"

# ------------------------------------------------------------------------------
# Waveform Generation (VCD Dump)
# ------------------------------------------------------------------------------
wave: asm
	@echo "=== Generating Waveform Dump (single_cycle.vcd) ==="
	@mkdir -p build
	$(IVERILOG) -g2012 -Irtl -DTEST_HEX='"tests/asm/sum10.hex"' -o build/sim_wave rtl/*.sv tests/integration/tb_programs.sv
	$(VVP) build/sim_wave
	@echo "Simulation finished. Waveform written."

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
clean:
	rm -rf build sim_* *.vcd trace_*.txt synth/*.log
