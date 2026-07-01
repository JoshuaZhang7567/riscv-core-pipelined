import riscv_pkg::*;

module imem
#(
    parameter int unsigned DEPTH      = 1024,
    parameter              MEM_INIT_F = ""
)
(
    input  logic [XLEN-1:0] pc_addr,
    output logic [XLEN-1:0] instr
);

    logic [XLEN-1:0] rom [0:DEPTH-1];

    initial begin
        if (MEM_INIT_F != "") $readmemh(MEM_INIT_F, rom);
        else for (int i = 0; i < DEPTH; i++) rom[i] = 32'h0000_0013; // NOP
    end

    // Word-aligned addressing
    localparam int WORD_ADDR_W = $clog2(DEPTH);
    logic [WORD_ADDR_W-1:0] word_addr;
    assign word_addr = pc_addr[WORD_ADDR_W+1:2];

    assign instr = rom[word_addr];

endmodule
