# --- Tools and paths (override on the command line, e.g. make IVFLAGS=...) ---
IVERILOG ?= iverilog
IVFLAGS  := -g2012
BUILD    := build
SIM      := $(BUILD)/tb_riscv_universal.vvp
TESTDIR := sw/asm
TEST_HEX := $(wildcard $(TESTDIR)/*.hex)
PASSES := $(patsubst $(TESTDIR)/%.hex,$(BUILD)/%.pass,$(TEST_HEX))
TESTS := $(patsubst $(TESTDIR)/%.hex,%,$(TEST_HEX))
T ?= test_basic
WAVE_VIEWER ?= surfer

# All sources, in compile order (package first: other files import it)
RTL_SRC  := rtl/riscv_pkg.sv \
            rtl/lib/adder.sv rtl/lib/mux2.sv rtl/lib/mux3.sv \
            rtl/core/pc.sv rtl/core/alu.sv rtl/core/regfile.sv \
            rtl/core/immgen.sv rtl/core/control.sv \
            rtl/core/hazard.sv \
            rtl/mem/imem.sv rtl/mem/dmem.sv \
            rtl/top/riscv_top.sv
SRC      := $(RTL_SRC) tb/system/tb_riscv_universal.sv

# --- FPGA (Terasic DE1-SoC) ---
FPGA_DIR     := fpga/de1soc
FPGA_HEX     := $(FPGA_DIR)/led_counter.hex
FPGA_SIM     := $(BUILD)/tb_de1soc_top.vvp
FPGA_SIM_SRC := $(RTL_SRC) rtl/fpga/hex7seg.sv rtl/fpga/de1soc_top.sv \
                tb/fpga/tb_de1soc_top.sv

# If a recipe fails, delete the target it was writing
.DELETE_ON_ERROR:

# Default goal: first target in the file
all: compile

test:
	-$(MAKE) -k run
	@pass=0; fail=0; \
	for t in $(TESTS); do \
	  if [ -f $(BUILD)/$$t.pass ] && grep -q "RESULT: PASS" $(BUILD)/$$t.log 2>/dev/null; then \
	    echo "  PASS  $$t"; pass=$$((pass+1)); \
	  else \
	    echo "  FAIL  $$t   (see $(BUILD)/$$t.log)"; fail=$$((fail+1)); \
	  fi; \
	done; \
	echo "  $$pass passed, $$fail failed"; \
	[ $$fail -eq 0 ]


run: $(PASSES)

waves: $(BUILD)/$(T).vcd
	$(WAVE_VIEWER) $< &

compile: $(SIM)

# Compile once; rebuilds only when a source is newer than the binary
$(SIM): $(SRC)
	mkdir -p $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# Run one test. The .log is always kept for debugging;
# the .pass marker exists only if this run passed.
$(BUILD)/%.pass: $(SIM) $(TESTDIR)/%.hex $(TESTDIR)/%.expected
	rm -f $@
	vvp -n $(SIM) +HEX_FILE=$(TESTDIR)/$*.hex +EXPECTED=$(TESTDIR)/$*.expected > $(BUILD)/$*.log
	touch $@

$(BUILD)/%.vcd: $(SIM) $(TESTDIR)/%.hex $(TESTDIR)/%.expected
	-vvp -n $(SIM) +HEX_FILE=$(TESTDIR)/$*.hex +EXPECTED=$(TESTDIR)/$*.expected +VCD=$@ > $(BUILD)/$*.wave.log

# --- FPGA targets ---
# Demo program ROM image for the board
$(FPGA_HEX): tools/gen_led_counter.py tools/gen_test.py
	python3 tools/gen_led_counter.py

# Simulate the board wrapper running the demo program
fpga-sim: $(FPGA_SIM) $(FPGA_HEX)
	vvp -n $(FPGA_SIM) | tee $(BUILD)/fpga_sim.log
	grep -q "RESULT: PASS" $(BUILD)/fpga_sim.log

$(FPGA_SIM): $(FPGA_SIM_SRC)
	mkdir -p $(BUILD)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

clean:
	rm -rf $(BUILD)

.PHONY: all compile clean test run waves fpga-sim
