# ===========================================================================
# RISC-V RV32I CPU — Project Makefile
# ===========================================================================

CC        = iverilog
CFLAGS    = -g2012    # SystemVerilog 2012

# --- Directories ---
CORE_DIR  = rtl/core
MEM_DIR   = rtl/mem
PERIPH_DIR= rtl/periph
TOP_DIR   = rtl/top
TB_SYS    = tb/system
WAVE_DIR  = sim/waveforms

# --- Package (must be compiled first) ---
PKG       = rtl/riscv_pkg.sv

# --- All RTL source files ---
RTL_SRC   = $(PKG) \
            rtl/lib/adder.sv rtl/lib/mux2.sv rtl/lib/mux3.sv \
            rtl/lib/flopr.sv rtl/lib/flopenr.sv \
            $(CORE_DIR)/pc.sv $(CORE_DIR)/alu.sv $(CORE_DIR)/regfile.sv \
            $(CORE_DIR)/immgen.sv $(CORE_DIR)/control.sv \
            $(MEM_DIR)/imem.sv $(MEM_DIR)/dmem.sv \
            $(TOP_DIR)/riscv_top.sv

# --- Universal testbench ---
UNIV_SRC  = $(RTL_SRC) $(TB_SYS)/tb_riscv_universal.sv
UNIV_OUT  = $(WAVE_DIR)/tb_riscv_universal.out

# Compile (only needs to happen once unless RTL changes)
test_compile:
	mkdir -p $(WAVE_DIR)
	$(CC) $(CFLAGS) -o $(UNIV_OUT) $(UNIV_SRC)

# Run a single test
test: test_compile
	vvp $(UNIV_OUT) +HEX_FILE=$(HEX) +EXPECTED=$(EXP)

# Run all tests
test_all: test_compile
	@echo ""
	@echo "============================================================"
	@echo "  Running all tests..."
	@echo "============================================================"
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_basic.hex    +EXPECTED=sw/asm/test_basic.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_alu.hex      +EXPECTED=sw/asm/test_alu.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_branches.hex +EXPECTED=sw/asm/test_branches.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_memory.hex   +EXPECTED=sw/asm/test_memory.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_upper.hex    +EXPECTED=sw/asm/test_upper.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_edge.hex     +EXPECTED=sw/asm/test_edge.expected
	@vvp $(UNIV_OUT) +HEX_FILE=sw/asm/test_fibonacci.hex +EXPECTED=sw/asm/test_fibonacci.expected

test_wave:
	gtkwave $(WAVE_DIR)/riscv_universal.vcd &

# ===========================================================================
# Helpers
# ===========================================================================
clean:
	rm -rf $(WAVE_DIR)/*.out $(WAVE_DIR)/*.vcd

.PHONY: test_compile test test_all test_wave clean
