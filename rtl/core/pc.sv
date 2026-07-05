import riscv_pkg::*;

module pc (input  logic             clk, reset, en,
           input  logic [XLEN-1:0]  pc_next,
           output logic [XLEN-1:0]  pc_out);

  // Resets to 0, latches pc_next on rising edge when enabled
  always_ff @(posedge clk, posedge reset)
    if (reset)    pc_out <= '0;
    else if (en)  pc_out <= pc_next;

endmodule
