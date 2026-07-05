// ============================================================================
// 5-Stage Pipelined RV32I CPU Top Module
//
// Stages:  IF → ID → EX → MEM → WB
// Pipeline registers: IF/ID (with stall+flush), ID/EX (flush), EX/MEM, MEM/WB
// Features: Data forwarding, load-use stall, branch/jump flush
// ============================================================================

import riscv_pkg::*;

module riscv_top #(
    parameter              IMEM_INIT_F     = "",
    parameter int unsigned IMEM_DEPTH      = 1024,
    parameter int unsigned DMEM_DEPTH      = 1024
) (
    input  logic clk,
    input  logic reset
);

    // ========================================================================
    //  Hazard Unit Signals
    // ========================================================================
    logic        stallF, stallD, flushD, flushE;
    logic [1:0]  forwardAE, forwardBE;

    // ========================================================================
    //  FETCH (IF) Stage
    // ========================================================================
    logic [XLEN-1:0] pc_F, pc_plus4_F, pc_next_F;
    logic [XLEN-1:0] instr_F;

    // Branch/jump targets from EX stage (declared here for PC mux)
    logic [XLEN-1:0] pc_target_E;   // PC + imm (branch/JAL)
    logic [XLEN-1:0] jalr_target_E; // ALU result & ~1 (JALR)
    logic [1:0]      pc_src_E;      // from EX stage branch resolution

    // PC Register (with stall support)
    pc pc_reg (
        .clk     (clk),
        .reset   (reset),
        .en      (~stallF),
        .pc_next (pc_next_F),
        .pc_out  (pc_F)
    );

    // PC + 4
    adder #(.WIDTH(XLEN)) pc_add4_F (
        .a (pc_F),
        .b (32'd4),
        .y (pc_plus4_F)
    );

    // PC source mux: 00=PC+4, 01=PC+Imm (branch/JAL), 10=JALR target
    mux3 #(.WIDTH(XLEN)) pc_mux (
        .d0 (pc_plus4_F),
        .d1 (pc_target_E),
        .d2 (jalr_target_E),
        .s  (pc_src_E),
        .y  (pc_next_F)
    );

    // Instruction Memory
    imem #(
        .DEPTH      (IMEM_DEPTH),
        .MEM_INIT_F (IMEM_INIT_F)
    ) instr_mem (
        .pc_addr (pc_F),
        .instr   (instr_F)
    );

    // ========================================================================
    //  IF/ID Pipeline Register (stall + flush)
    // ========================================================================
    logic [XLEN-1:0] instr_D, pc_D, pc_plus4_D;

    always_ff @(posedge clk, posedge reset)
        if (reset || flushD) begin
            instr_D    <= 32'h0000_0013; // NOP (addi x0, x0, 0)
            pc_D       <= '0;
            pc_plus4_D <= '0;
        end else if (~stallD) begin
            instr_D    <= instr_F;
            pc_D       <= pc_F;
            pc_plus4_D <= pc_plus4_F;
        end

    // ========================================================================
    //  DECODE (ID) Stage
    // ========================================================================

    // Instruction field extraction
    logic [4:0] rs1_D, rs2_D, rd_D;
    assign rs1_D = instr_D[19:15];
    assign rs2_D = instr_D[24:20];
    assign rd_D  = instr_D[11:7];

    // Control signals (from control unit)
    logic             reg_write_D;
    alu_control_t     alu_ctrl_D;
    logic             alu_src_1_D;
    logic             alu_src_2_D;
    logic             mem_write_D;
    logic             mem_read_D;
    mem_size_t        mem_size_D;
    logic             mem_unsigned_D;
    result_src_t      result_src_D;
    imm_src_t         imm_src_D;
    logic             branch_D;
    logic             jump_D;

    // Control Unit
    control ctrl (
        .opcode      (opcode_t'(instr_D[6:0])),
        .funct3      (instr_D[14:12]),
        .funct7      (instr_D[31:25]),
        .reg_write   (reg_write_D),
        .alu_control (alu_ctrl_D),
        .alu_src_1   (alu_src_1_D),
        .alu_src_2   (alu_src_2_D),
        .mem_write   (mem_write_D),
        .mem_read    (mem_read_D),
        .mem_size    (mem_size_D),
        .mem_unsigned(mem_unsigned_D),
        .result_src  (result_src_D),
        .imm_src     (imm_src_D),
        .branch      (branch_D),
        .jump        (jump_D)
    );

    // Register File (reads in ID, writes in WB)
    logic [XLEN-1:0] rd1_D, rd2_D;
    logic [XLEN-1:0] result_W;      // write-back data from WB stage
    logic             reg_write_W;   // write enable from WB stage
    logic [4:0]       rd_W;          // destination register from WB stage

    regfile rf (
        .clk        (clk),
        .reg_write  (reg_write_W),
        .rd         (rd_W),
        .write_data (result_W),
        .rs1        (rs1_D),
        .read_data1 (rd1_D),
        .rs2        (rs2_D),
        .read_data2 (rd2_D)
    );

    // Immediate Generator
    logic [XLEN-1:0] immext_D;

    immgen imm_gen (
        .instr  (instr_D[31:7]),
        .immsrc (imm_src_D),
        .immext (immext_D)
    );

    // ========================================================================
    //  ID/EX Pipeline Register (flush only, no stall)
    // ========================================================================
    // Control signals
    logic             reg_write_E;
    alu_control_t     alu_ctrl_E;
    logic             alu_src_1_E, alu_src_2_E;
    logic             mem_write_E, mem_read_E;
    mem_size_t        mem_size_E;
    logic             mem_unsigned_E;
    result_src_t      result_src_E;
    logic             branch_E, jump_E;
    logic [2:0]       funct3_E;

    // Data signals
    logic [XLEN-1:0] rd1_E, rd2_E, pc_E, pc_plus4_E, immext_E;
    logic [4:0]      rs1_E, rs2_E, rd_E;

    always_ff @(posedge clk, posedge reset)
        if (reset || flushE) begin
            // Control — all zeros = NOP (no writes, no branches)
            reg_write_E    <= 1'b0;
            alu_ctrl_E     <= ALU_ADD;
            alu_src_1_E    <= 1'b0;
            alu_src_2_E    <= 1'b0;
            mem_write_E    <= 1'b0;
            mem_read_E     <= 1'b0;
            mem_size_E     <= MEM_WORD;
            mem_unsigned_E <= 1'b0;
            result_src_E   <= RESULT_ALU;
            branch_E       <= 1'b0;
            jump_E         <= 1'b0;
            funct3_E       <= 3'b0;
            // Data
            rd1_E          <= '0;
            rd2_E          <= '0;
            pc_E           <= '0;
            pc_plus4_E     <= '0;
            immext_E       <= '0;
            rs1_E          <= 5'b0;
            rs2_E          <= 5'b0;
            rd_E           <= 5'b0;
        end else begin
            reg_write_E    <= reg_write_D;
            alu_ctrl_E     <= alu_ctrl_D;
            alu_src_1_E    <= alu_src_1_D;
            alu_src_2_E    <= alu_src_2_D;
            mem_write_E    <= mem_write_D;
            mem_read_E     <= mem_read_D;
            mem_size_E     <= mem_size_D;
            mem_unsigned_E <= mem_unsigned_D;
            result_src_E   <= result_src_D;
            branch_E       <= branch_D;
            jump_E         <= jump_D;
            funct3_E       <= instr_D[14:12];
            rd1_E          <= rd1_D;
            rd2_E          <= rd2_D;
            pc_E           <= pc_D;
            pc_plus4_E     <= pc_plus4_D;
            immext_E       <= immext_D;
            rs1_E          <= rs1_D;
            rs2_E          <= rs2_D;
            rd_E           <= rd_D;
        end

    // ========================================================================
    //  EXECUTE (EX) Stage
    // ========================================================================

    // -- Forwarding muxes --
    logic [XLEN-1:0] src_a_fwd, src_b_fwd;
    logic [XLEN-1:0] alu_result_M;  // forwarded from MEM stage
    // result_W already declared above (forwarded from WB stage)

    // Forward A: 00=rd1_E, 01=result_W, 10=alu_result_M
    mux3 #(.WIDTH(XLEN)) fwd_a_mux (
        .d0 (rd1_E),
        .d1 (result_W),
        .d2 (alu_result_M),
        .s  (forwardAE),
        .y  (src_a_fwd)
    );

    // Forward B: 00=rd2_E, 01=result_W, 10=alu_result_M
    mux3 #(.WIDTH(XLEN)) fwd_b_mux (
        .d0 (rd2_E),
        .d1 (result_W),
        .d2 (alu_result_M),
        .s  (forwardBE),
        .y  (src_b_fwd)
    );

    // -- ALU source muxes --
    logic [XLEN-1:0] alu_a, alu_b;

    // ALU A: 0=forwarded rs1, 1=PC (for AUIPC/branch target)
    mux2 #(.WIDTH(XLEN)) alu_a_mux (
        .d0 (src_a_fwd),
        .d1 (pc_E),
        .s  (alu_src_1_E),
        .y  (alu_a)
    );

    // ALU B: 0=forwarded rs2, 1=ImmExt
    mux2 #(.WIDTH(XLEN)) alu_b_mux (
        .d0 (src_b_fwd),
        .d1 (immext_E),
        .s  (alu_src_2_E),
        .y  (alu_b)
    );

    // -- ALU --
    logic [XLEN-1:0] alu_result_E;
    logic             alu_zero_E;

    alu main_alu (
        .a           (alu_a),
        .b           (alu_b),
        .alu_control (alu_ctrl_E),
        .result      (alu_result_E),
        .zero        (alu_zero_E)
    );

    // -- Branch/Jump target computation --
    // Branch/JAL target: PC_E + imm_E
    adder #(.WIDTH(XLEN)) pc_add_imm_E (
        .a (pc_E),
        .b (immext_E),
        .y (pc_target_E)
    );

    // JALR target: (ALU result) & ~1
    assign jalr_target_E = {alu_result_E[XLEN-1:1], 1'b0};

    // -- Branch resolution (determines pc_src_E for hazard unit + PC mux) --
    logic branch_taken_E;

    always_comb begin
        if (branch_E) begin
            case (funct3_E)
                3'b000:  branch_taken_E =  alu_zero_E;  // BEQ
                3'b001:  branch_taken_E = ~alu_zero_E;   // BNE
                3'b100:  branch_taken_E = ~alu_zero_E;   // BLT  (SLT==1 → result!=0)
                3'b101:  branch_taken_E =  alu_zero_E;   // BGE  (SLT==0 → result==0)
                3'b110:  branch_taken_E = ~alu_zero_E;   // BLTU
                3'b111:  branch_taken_E =  alu_zero_E;   // BGEU
                default: branch_taken_E = 1'b0;
            endcase
        end else begin
            branch_taken_E = 1'b0;
        end
    end

    // PC source: 00=PC+4, 01=branch/JAL target, 10=JALR target
    always_comb begin
        if (jump_E && alu_src_2_E)              // JALR (uses rs1+imm via ALU)
            pc_src_E = 2'b10;
        else if (jump_E || branch_taken_E)      // JAL or taken branch
            pc_src_E = 2'b01;
        else
            pc_src_E = 2'b00;                   // sequential (PC+4)
    end

    // Write data for stores = forwarded rs2 value
    logic [XLEN-1:0] write_data_E;
    assign write_data_E = src_b_fwd;

    // ========================================================================
    //  EX/MEM Pipeline Register
    // ========================================================================
    // Control
    logic             reg_write_M;
    logic             mem_write_M, mem_read_M;
    mem_size_t        mem_size_M;
    logic             mem_unsigned_M;
    result_src_t      result_src_M;
    // Data
    // alu_result_M declared above (used by forwarding muxes)
    logic [XLEN-1:0] write_data_M, pc_plus4_M;
    logic [4:0]      rd_M;

    always_ff @(posedge clk, posedge reset)
        if (reset) begin
            reg_write_M    <= 1'b0;
            mem_write_M    <= 1'b0;
            mem_read_M     <= 1'b0;
            mem_size_M     <= MEM_WORD;
            mem_unsigned_M <= 1'b0;
            result_src_M   <= RESULT_ALU;
            alu_result_M   <= '0;
            write_data_M   <= '0;
            pc_plus4_M     <= '0;
            rd_M           <= 5'b0;
        end else begin
            reg_write_M    <= reg_write_E;
            mem_write_M    <= mem_write_E;
            mem_read_M     <= mem_read_E;
            mem_size_M     <= mem_size_E;
            mem_unsigned_M <= mem_unsigned_E;
            result_src_M   <= result_src_E;
            alu_result_M   <= alu_result_E;
            write_data_M   <= write_data_E;
            pc_plus4_M     <= pc_plus4_E;
            rd_M           <= rd_E;
        end

    // ========================================================================
    //  MEMORY (MEM) Stage
    // ========================================================================
    logic [XLEN-1:0] mem_read_data_M;

    dmem #(.DEPTH(DMEM_DEPTH)) data_mem (
        .clk          (clk),
        .mem_write    (mem_write_M),
        .mem_read     (mem_read_M),
        .mem_size     (mem_size_M),
        .mem_unsigned (mem_unsigned_M),
        .addr         (alu_result_M),
        .write_data   (write_data_M),
        .read_data    (mem_read_data_M)
    );

    // ========================================================================
    //  MEM/WB Pipeline Register
    // ========================================================================
    // reg_write_W, rd_W, result_W declared above (used by regfile + forwarding)
    logic [XLEN-1:0] alu_result_W, read_data_W, pc_plus4_W;
    result_src_t      result_src_W;

    always_ff @(posedge clk, posedge reset)
        if (reset) begin
            reg_write_W  <= 1'b0;
            result_src_W <= RESULT_ALU;
            alu_result_W <= '0;
            read_data_W  <= '0;
            pc_plus4_W   <= '0;
            rd_W         <= 5'b0;
        end else begin
            reg_write_W  <= reg_write_M;
            result_src_W <= result_src_M;
            alu_result_W <= alu_result_M;
            read_data_W  <= mem_read_data_M;
            pc_plus4_W   <= pc_plus4_M;
            rd_W         <= rd_M;
        end

    // ========================================================================
    //  WRITEBACK (WB) Stage
    // ========================================================================

    // Result mux: 00=ALU, 01=MEM, 10=PC+4
    mux3 #(.WIDTH(XLEN)) result_mux (
        .d0 (alu_result_W),
        .d1 (read_data_W),
        .d2 (pc_plus4_W),
        .s  (result_src_W),
        .y  (result_W)
    );

    // result_W → regfile write port (wired above in ID stage regfile instance)

    // ========================================================================
    //  Hazard Unit
    // ========================================================================
    hazard hazard_unit (
        // Fetch
        .stallF    (stallF),
        // Decode
        .rs1D      (rs1_D),
        .rs2D      (rs2_D),
        .stallD    (stallD),
        .flushD    (flushD),
        // Execute
        .rs1E      (rs1_E),
        .rs2E      (rs2_E),
        .rdE       (rd_E),
        .pcSrcE    (pc_src_E),
        .memReadE  (mem_read_E),
        .forwardAE (forwardAE),
        .forwardBE (forwardBE),
        .flushE    (flushE),
        // Memory
        .rdM       (rd_M),
        .regWriteM (reg_write_M),
        // Writeback
        .rdW       (rd_W),
        .regWriteW (reg_write_W)
    );

endmodule
