// ============================================================================
// Hazard Unit for 5-Stage Pipelined RV32I CPU
//
// Responsibilities:
// 1. Data Forwarding: Route newer data from MEM or WB stages back to EX stage.
// 2. Load-Use Stalls: Freeze IF and ID stages if a Load instruction is active.
// 3. Control Flushes: Clear instructions in IF and ID if a branch/jump is taken.
// ============================================================================

module hazard (
    // ---- Fetch Stage Signals ----
    output logic       stallF,      // Freeze the PC

    // ---- Decode Stage Signals ----
    input  logic [4:0] rs1D,        // Source reg 1 in Decode
    input  logic [4:0] rs2D,        // Source reg 2 in Decode
    output logic       stallD,      // Freeze the IF/ID pipeline register
    output logic       flushD,      // Clear the IF/ID pipeline register

    // ---- Execute Stage Signals ----
    input  logic [4:0] rs1E,        // Source reg 1 in Execute
    input  logic [4:0] rs2E,        // Source reg 2 in Execute
    input  logic [4:0] rdE,         // Destination reg in Execute
    input  logic [1:0] pcSrcE,      // 2-bit PC source (00=PC+4, 01=Branch/JAL, 10=JALR)
    input  logic       memReadE,    // 1 if instruction in Execute is a Load (LW)
    output logic [1:0] forwardAE,   // Select line for ALU Input A mux3
    output logic [1:0] forwardBE,   // Select line for ALU Input B mux3
    output logic       flushE,      // Clear the ID/EX pipeline register

    // ---- Memory Stage Signals ----
    input  logic [4:0] rdM,         // Destination reg in Memory
    input  logic       regWriteM,   // 1 if instruction in Memory writes to a reg

    // ---- Writeback Stage Signals ----
    input  logic [4:0] rdW,         // Destination reg in Writeback
    input  logic       regWriteW    // 1 if instruction in Writeback writes to a reg
);

    // ========================================================================
    // 1. DATA FORWARDING LOGIC (Bypassing)
    // ========================================================================
    // If the Execute stage needs a register that the MEM or WB stage is 
    // currently working on, forward the data directly to the ALU mux3s.
    // Note: We check `rd != 0` because RISC-V register x0 is hardwired to 0.
    
    always_comb begin
        // Forwarding for ALU Input A (rs1)
        if (((rs1E == rdM) && regWriteM) && (rs1E != 0)) 
            forwardAE = 2'b10; // Forward from Memory stage (most recent)
        else if (((rs1E == rdW) && regWriteW) && (rs1E != 0)) 
            forwardAE = 2'b01; // Forward from Writeback stage (older)
        else 
            forwardAE = 2'b00; // No hazard, use standard register file output

        // Forwarding for ALU Input B (rs2)
        if (((rs2E == rdM) && regWriteM) && (rs2E != 0)) 
            forwardBE = 2'b10; // Forward from Memory stage
        else if (((rs2E == rdW) && regWriteW) && (rs2E != 0)) 
            forwardBE = 2'b01; // Forward from Writeback stage
        else 
            forwardBE = 2'b00; // No hazard, use standard register file output
    end

    // ========================================================================
    // 2. LOAD-USE STALL LOGIC
    // ========================================================================
    // If the instruction in Execute is a Load (memReadE), and it is writing 
    // to a register (rdE) that the instruction in Decode currently needs 
    // (rs1D or rs2D), we MUST stall for 1 clock cycle to wait for RAM.
    //
    // FIX: Added (rdE != 0) guard. Without it, a load targeting x0
    // (e.g. "lw x0, 0(x1)") would incorrectly trigger a stall whenever
    // the instruction in Decode reads x0 as rs1D/rs2D (very common for
    // "don't care" operand fields), even though x0 is hardwired to 0
    // and no real hazard exists.
    
    logic lwStall;

    always_comb begin
        lwStall = memReadE && (rdE != 0) && ((rs1D == rdE) || (rs2D == rdE));
    end

    // ========================================================================
    // 3. STALL & FLUSH ASSIGNMENTS
    // ========================================================================
    
    // Stall Fetch and Decode if there is a Load-Use hazard
    assign stallF = lwStall;
    assign stallD = lwStall;

    // Flush Execute stage if there is a Load-Use hazard (to insert a bubble)
    // OR if a branch/jump is taken (because the instruction in EX is wrong)
    assign flushE = lwStall || (pcSrcE != 2'b00);

    // Flush Decode stage if a branch/jump is taken (the fetched instruction is wrong)
    assign flushD = (pcSrcE != 2'b00);

endmodule
