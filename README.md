# riscv-core-pipelined

A 5-stage pipelined RV32I RISC-V CPU core written in SystemVerilog.

## Project Structure

```
riscv-core-pipelined/
├── docs/                 # Specifications, diagrams, ISA references
│   └── architecture.md
├── rtl/                  # SystemVerilog hardware source files
│   ├── core/             # CPU core modules (ALU, RegFile, Control, Datapath)
│   ├── lib/              # Generic primitives (mux2, mux3, adder, flopr, flopenr)
│   ├── mem/              # Memory components (RAM, ROM wrappers)
│   ├── periph/           # Peripherals (UART, GPIO, timers)
│   └── top/              # Top-level integration and FPGA wrappers
├── tb/                   # Testbenches
│   ├── unit/             # Module-level testbenches (e.g., tb_alu.sv)
│   └── system/           # Full system testbenches (e.g., tb_top.sv)
├── sim/                  # Simulation scripts and outputs
│   ├── makefiles/        # Makefiles for ModelSim, Verilator, or Icarus
│   └── waveforms/        # Output directory for .vcd / .fst waveform files
├── sw/                   # Software and testing programs
│   ├── asm/              # Hand-written assembly tests
│   ├── c/                # C programs for testing
│   ├── linker/           # Custom linker scripts (.ld)
│   └── scripts/          # Python/Bash scripts for ELF-to-Hex conversion
└── synth/                # FPGA synthesis and implementation files
    ├── constraints/      # Pin mappings (.xdc for Xilinx, .qsf for Intel)
    └── project/          # Vivado or Quartus project files
```

## Prerequisites & Local Setup

This CPU is written in SystemVerilog and simulated using **Icarus Verilog**.

### 1. Install the Simulation Toolchain (macOS)

You will need Homebrew to install the simulation engine and waveform viewer. Open your terminal and run:

```bash
# Install Icarus Verilog (The Compiler/Simulator)
brew install icarus-verilog

# Install GTKWave (The Waveform Viewer)
brew install --cask gtkwave
```

### 2. Build & Run

```bash
# Compile and run all tests
make test_all

# Run a single test
make test HEX=sw/asm/test_basic.hex EXP=sw/asm/test_basic.expected

# Open waveforms in GTKWave
make test_wave

# Clean simulation artifacts
make clean
```