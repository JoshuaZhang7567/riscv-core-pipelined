// Shared package for the RV32I single-cycle CPU.

package riscv_pkg;

  // Word widths
  localparam int XLEN       = 32;
  localparam int REG_ADDR_W = 5;
  localparam int NUM_REGS   = 32;

  // Opcodes — instr[6:0]
  typedef enum logic [6:0] {
    OP_LUI      = 7'b0110111,
    OP_AUIPC    = 7'b0010111,
    OP_JAL      = 7'b1101111,
    OP_JALR     = 7'b1100111,
    OP_BRANCH   = 7'b1100011,
    OP_LOAD     = 7'b0000011,
    OP_STORE    = 7'b0100011,
    OP_IMM      = 7'b0010011,
    OP_REG      = 7'b0110011,
    OP_FENCE    = 7'b0001111,
    OP_SYSTEM   = 7'b1110011
  } opcode_t;

  // funct3 — ALU R-type & I-type
  typedef enum logic [2:0] {
    F3_ADD_SUB  = 3'b000,       // ADD/SUB (funct7 distinguishes)
    F3_SLL      = 3'b001,
    F3_SLT      = 3'b010,
    F3_SLTU     = 3'b011,
    F3_XOR      = 3'b100,
    F3_SRL_SRA  = 3'b101,       // SRL/SRA (funct7 distinguishes)
    F3_OR       = 3'b110,
    F3_AND      = 3'b111
  } funct3_alu_t;

  // funct3 — Branch
  typedef enum logic [2:0] {
    F3_BEQ      = 3'b000,
    F3_BNE      = 3'b001,
    F3_BLT      = 3'b100,
    F3_BGE      = 3'b101,
    F3_BLTU     = 3'b110,
    F3_BGEU     = 3'b111
  } funct3_branch_t;

  // funct3 — Load
  typedef enum logic [2:0] {
    F3_LB       = 3'b000,
    F3_LH       = 3'b001,
    F3_LW       = 3'b010,
    F3_LBU      = 3'b100,
    F3_LHU      = 3'b101
  } funct3_load_t;

  // funct3 — Store
  typedef enum logic [2:0] {
    F3_SB       = 3'b000,
    F3_SH       = 3'b001,
    F3_SW       = 3'b010
  } funct3_store_t;

  // funct7
  typedef enum logic [6:0] {
    F7_NORMAL   = 7'b0000000,   // ADD, SRL, etc.
    F7_ALT      = 7'b0100000    // SUB, SRA
  } funct7_t;

  // ResultSrc — write-back mux
  typedef enum logic [1:0] {
    RESULT_ALU      = 2'b00,
    RESULT_MEM      = 2'b01,
    RESULT_PC4      = 2'b10     // JAL/JALR return address
  } result_src_t;

  // ImmSrc — immediate format select
  typedef enum logic [2:0] {
    IMM_I       = 3'b000,
    IMM_S       = 3'b001,
    IMM_B       = 3'b010,
    IMM_U       = 3'b011,
    IMM_J       = 3'b100
  } imm_src_t;

  // MemSize — byte/half/word access
  typedef enum logic [1:0] {
    MEM_BYTE    = 2'b00,
    MEM_HALF    = 2'b01,
    MEM_WORD    = 2'b10
  } mem_size_t;

  // ALUOp — main decoder → ALU decoder
  typedef enum logic [1:0] {
    ALUOP_ADD    = 2'b00,       // Force ADD (loads/stores/AUIPC)
    ALUOP_SUB    = 2'b01,       // Force SUB (branches)
    ALUOP_FUNC   = 2'b10       // Decode from funct3+funct7
  } alu_op_t;

  // ALU operation select
  typedef enum logic [3:0] {
    ALU_ADD     = 4'b0000,
    ALU_SUB     = 4'b0001,
    ALU_AND     = 4'b0010,
    ALU_OR      = 4'b0011,
    ALU_XOR     = 4'b0100,
    ALU_SLT     = 4'b0101,
    ALU_SLTU    = 4'b0110,
    ALU_SLL     = 4'b0111,
    ALU_SRL     = 4'b1000,
    ALU_SRA     = 4'b1001,
    ALU_PASS_B  = 4'b1010       // Pass B through (LUI)
  } alu_control_t;

  // Instruction field extraction
  function automatic logic [6:0] get_op(input logic [31:0] instr);
    return instr[6:0];
  endfunction

  function automatic logic [4:0] get_rd(input logic [31:0] instr);
    return instr[11:7];
  endfunction

  function automatic logic [2:0] get_funct3(input logic [31:0] instr);
    return instr[14:12];
  endfunction

  function automatic logic [4:0] get_rs1(input logic [31:0] instr);
    return instr[19:15];
  endfunction

  function automatic logic [4:0] get_rs2(input logic [31:0] instr);
    return instr[24:20];
  endfunction

  function automatic logic [6:0] get_funct7(input logic [31:0] instr);
    return instr[31:25];
  endfunction

  // Sign-extended immediate extraction
  function automatic logic [31:0] get_imm_i(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:20]};
  endfunction

  function automatic logic [31:0] get_imm_s(input logic [31:0] instr);
    return {{20{instr[31]}}, instr[31:25], instr[11:7]};
  endfunction

  function automatic logic [31:0] get_imm_b(input logic [31:0] instr);
    return {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  endfunction

  function automatic logic [31:0] get_imm_u(input logic [31:0] instr);
    return {instr[31:12], 12'b0};
  endfunction

  function automatic logic [31:0] get_imm_j(input logic [31:0] instr);
    return {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  endfunction

endpackage
