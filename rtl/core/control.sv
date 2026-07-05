// Control Unit — decodes opcode/funct3/funct7 into datapath control signals.
// Covers all 40 unprivileged RV32I instructions.
//
// Pipeline note: Branch resolution (pc_src) is NOT computed here.
// The `branch` and `jump` flags are piped to EX, where the ALU zero flag
// and funct3 determine pc_src.

import riscv_pkg::*;

module control (
    // Instruction fields
    input  opcode_t              opcode,
    input  logic [2:0]           funct3,
    input  logic [6:0]           funct7,

    // Control outputs
    output logic                 reg_write,
    output alu_control_t         alu_control,
    output logic                 alu_src_1,    // 0=rs1, 1=PC
    output logic                 alu_src_2,    // 0=rs2, 1=ImmExt
    output logic                 mem_write,
    output logic                 mem_read,
    output mem_size_t            mem_size,
    output logic                 mem_unsigned, // 0=sign-ext, 1=zero-ext
    output result_src_t          result_src,   // ALU=00, MEM=01, PC+4=10
    output imm_src_t             imm_src,
    output logic                 branch,       // 1 = conditional branch
    output logic                 jump          // 1 = JAL or JALR
);

    always_comb begin
        // Safe defaults — no writes, no branches
        reg_write    = 1'b0;
        alu_control  = ALU_ADD;
        alu_src_1    = 1'b0;
        alu_src_2    = 1'b0;
        mem_write    = 1'b0;
        mem_read     = 1'b0;
        mem_size     = MEM_WORD;
        mem_unsigned = 1'b0;
        result_src   = RESULT_ALU;
        imm_src      = IMM_I;
        branch       = 1'b0;
        jump         = 1'b0;

        case (opcode)

            // R-type
            OP_REG: begin
                reg_write  = 1'b1;
                alu_src_2  = 1'b0;
                result_src = RESULT_ALU;
                case (funct3)
                    F3_ADD_SUB: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SUB;
                        else                  alu_control = ALU_ADD;
                    end
                    F3_SLL:     alu_control = ALU_SLL;
                    F3_SLT:     alu_control = ALU_SLT;
                    F3_SLTU:    alu_control = ALU_SLTU;
                    F3_XOR:     alu_control = ALU_XOR;
                    F3_SRL_SRA: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SRA;
                        else                  alu_control = ALU_SRL;
                    end
                    F3_OR:      alu_control = ALU_OR;
                    F3_AND:     alu_control = ALU_AND;
                    default:    alu_control = ALU_ADD;
                endcase
            end

            // I-type ALU
            OP_IMM: begin
                reg_write  = 1'b1;
                alu_src_2  = 1'b1;          // immediate
                imm_src    = IMM_I;
                result_src = RESULT_ALU;
                case (funct3)
                    F3_ADD_SUB: alu_control = ALU_ADD;
                    F3_SLL:     alu_control = ALU_SLL;
                    F3_SLT:     alu_control = ALU_SLT;
                    F3_SLTU:    alu_control = ALU_SLTU;
                    F3_XOR:     alu_control = ALU_XOR;
                    F3_SRL_SRA: begin
                        if (funct7 == F7_ALT) alu_control = ALU_SRA;
                        else                  alu_control = ALU_SRL;
                    end
                    F3_OR:      alu_control = ALU_OR;
                    F3_AND:     alu_control = ALU_AND;
                    default:    alu_control = ALU_ADD;
                endcase
            end

            // Load: ALU computes base + offset
            OP_LOAD: begin
                reg_write    = 1'b1;
                alu_src_2    = 1'b1;
                alu_control  = ALU_ADD;
                mem_read     = 1'b1;
                result_src   = RESULT_MEM;
                imm_src      = IMM_I;
                mem_unsigned = funct3[2];   // LBU/LHU vs LB/LH
                case (funct3[1:0])
                    2'b00:   mem_size = MEM_BYTE;
                    2'b01:   mem_size = MEM_HALF;
                    default: mem_size = MEM_WORD;
                endcase
            end

            // Store: ALU computes base + offset
            OP_STORE: begin
                alu_src_2   = 1'b1;
                alu_control = ALU_ADD;
                mem_write   = 1'b1;
                imm_src     = IMM_S;
                case (funct3[1:0])
                    2'b00:   mem_size = MEM_BYTE;
                    2'b01:   mem_size = MEM_HALF;
                    default: mem_size = MEM_WORD;
                endcase
            end

            // Branch — ALU computes comparison, EX stage resolves taken/not-taken
            OP_BRANCH: begin
                branch    = 1'b1;
                alu_src_2 = 1'b0;
                imm_src   = IMM_B;

                // ALU op per branch type
                case (funct3)
                    F3_BEQ, F3_BNE:   alu_control = ALU_SUB;
                    F3_BLT, F3_BGE:   alu_control = ALU_SLT;
                    F3_BLTU, F3_BGEU: alu_control = ALU_SLTU;
                    default:          alu_control = ALU_SUB;
                endcase
            end

            // JAL: rd ← PC+4, PC ← PC+Imm
            OP_JAL: begin
                reg_write  = 1'b1;
                result_src = RESULT_PC4;
                jump       = 1'b1;
                imm_src    = IMM_J;
            end

            // JALR: rd ← PC+4, PC ← (rs1+Imm) & ~1
            OP_JALR: begin
                reg_write   = 1'b1;
                alu_src_2   = 1'b1;
                alu_control = ALU_ADD;
                result_src  = RESULT_PC4;
                jump        = 1'b1;
                imm_src     = IMM_I;
            end

            // LUI: rd ← ImmExt
            OP_LUI: begin
                reg_write   = 1'b1;
                alu_src_2   = 1'b1;
                alu_control = ALU_PASS_B;
                result_src  = RESULT_ALU;
                imm_src     = IMM_U;
            end

            // AUIPC: rd ← PC + ImmExt
            OP_AUIPC: begin
                reg_write   = 1'b1;
                alu_src_1   = 1'b1;         // PC
                alu_src_2   = 1'b1;
                alu_control = ALU_ADD;
                result_src  = RESULT_ALU;
                imm_src     = IMM_U;
            end

            // FENCE / ECALL / EBREAK — NOP
            OP_FENCE,
            OP_SYSTEM: begin
            end

            default: begin
            end

        endcase
    end

endmodule
