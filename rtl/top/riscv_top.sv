// Top-level single-cycle RV32I CPU — wires all datapath and control modules.

import riscv_pkg::*;

module riscv_top #(
    parameter              IMEM_INIT_F     = "",
    parameter int unsigned IMEM_DEPTH      = 1024,
    parameter int unsigned DMEM_DEPTH      = 1024
) (
    input  logic clk,
    input  logic reset
);

    // -- PC --
    logic [XLEN-1:0] pc_out;
    logic [XLEN-1:0] pc_next;
    logic [XLEN-1:0] pc_plus4;
    logic [XLEN-1:0] pc_plus_imm;
    logic [XLEN-1:0] jalr_target;

    // -- Instruction --
    logic [XLEN-1:0] instr;

    // -- Control signals --
    logic             reg_write;
    alu_control_t     alu_ctrl;
    logic             alu_src_1;        // 0=rs1, 1=PC
    logic             alu_src_2;        // 0=rs2, 1=ImmExt
    logic             mem_write_en;
    logic             mem_read_en;
    mem_size_t        mem_size;
    logic             mem_unsigned_en;
    result_src_t      result_src;
    logic [1:0]       pc_src;
    imm_src_t         imm_src;

    // -- Register File --
    logic [XLEN-1:0] read_data1;
    logic [XLEN-1:0] read_data2;
    logic [XLEN-1:0] write_back_data;

    // -- Immediate --
    logic [XLEN-1:0] immext;

    // -- ALU --
    logic [XLEN-1:0] alu_a;
    logic [XLEN-1:0] alu_b;
    logic [XLEN-1:0] alu_result;
    logic             alu_zero;

    // -- Data Memory --
    logic [XLEN-1:0] mem_read_data;

    // JALR: clear bit 0 per RISC-V spec
    assign jalr_target = {alu_result[XLEN-1:1], 1'b0};

    // PC Register
    pc pc_reg (
        .clk     (clk),
        .reset   (reset),
        .pc_next (pc_next),
        .pc_out  (pc_out)
    );

    // PC + 4
    adder #(.WIDTH(XLEN)) pc_add4 (
        .a (pc_out),
        .b (32'd4),
        .y (pc_plus4)
    );

    // PC + ImmExt (branch/JAL target)
    adder #(.WIDTH(XLEN)) pc_add_imm (
        .a (pc_out),
        .b (immext),
        .y (pc_plus_imm)
    );

    // PC source mux: 00=PC+4, 01=PC+Imm, 10=JALR
    mux3 #(.WIDTH(XLEN)) pc_mux (
        .d0 (pc_plus4),
        .d1 (pc_plus_imm),
        .d2 (jalr_target),
        .s  (pc_src),
        .y  (pc_next)
    );

    // Instruction Memory
    imem #(
        .DEPTH      (IMEM_DEPTH),
        .MEM_INIT_F (IMEM_INIT_F)
    ) instr_mem (
        .pc_addr (pc_out),
        .instr   (instr)
    );

    // Control Unit
    control ctrl (
        .opcode      (opcode_t'(instr[6:0])),
        .funct3      (instr[14:12]),
        .funct7      (instr[31:25]),
        .zero        (alu_zero),
        .reg_write   (reg_write),
        .alu_control (alu_ctrl),
        .alu_src_1   (alu_src_1),
        .alu_src_2   (alu_src_2),
        .mem_write   (mem_write_en),
        .mem_read    (mem_read_en),
        .mem_size    (mem_size),
        .mem_unsigned(mem_unsigned_en),
        .result_src  (result_src),
        .pc_src      (pc_src),
        .imm_src     (imm_src)
    );

    // Register File
    regfile rf (
        .clk        (clk),
        .reg_write  (reg_write),
        .rd         (instr[11:7]),
        .write_data (write_back_data),
        .rs1        (instr[19:15]),
        .read_data1 (read_data1),
        .rs2        (instr[24:20]),
        .read_data2 (read_data2)
    );

    // Immediate Generator
    immgen imm_gen (
        .instr  (instr[31:7]),
        .immsrc (imm_src),
        .immext (immext)
    );

    // ALU A mux: 0=rs1, 1=PC
    mux2 #(.WIDTH(XLEN)) alu_a_mux (
        .d0 (read_data1),
        .d1 (pc_out),
        .s  (alu_src_1),
        .y  (alu_a)
    );

    // ALU B mux: 0=rs2, 1=ImmExt
    mux2 #(.WIDTH(XLEN)) alu_b_mux (
        .d0 (read_data2),
        .d1 (immext),
        .s  (alu_src_2),
        .y  (alu_b)
    );

    // ALU
    alu main_alu (
        .a      (alu_a),
        .b      (alu_b),
        .alu_control (alu_ctrl),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // Data Memory
    dmem #(.DEPTH(DMEM_DEPTH)) data_mem (
        .clk          (clk),
        .mem_write    (mem_write_en),
        .mem_read     (mem_read_en),
        .mem_size     (mem_size),
        .mem_unsigned (mem_unsigned_en),
        .addr         (alu_result),
        .write_data   (read_data2),
        .read_data    (mem_read_data)
    );

    // Result mux: 00=ALU, 01=MEM, 10=PC+4
    mux3 #(.WIDTH(XLEN)) result_mux (
        .d0 (alu_result),
        .d1 (mem_read_data),
        .d2 (pc_plus4),
        .s  (result_src),
        .y  (write_back_data)
    );

endmodule
