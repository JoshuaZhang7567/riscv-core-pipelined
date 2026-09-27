// ============================================================================
// DE1-SoC board wrapper for the pipelined RV32I core
//
//   CLOCK_50   CPU clock (50 MHz)
//   KEY[0]     reset (active-low push-button)
//   SW[9:0]    readable by software at 0x8000_0004
//   LEDR[9:0]  io_out[9:0]  (software writes 0x8000_0000)
//   HEX5-HEX0  io_out[23:0] in hex
// ============================================================================

module de1soc_top #(
    parameter IMEM_INIT_F = "led_counter.hex"  // relative to the Quartus project dir
) (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    // ------------------------------------------------------------------------
    // Reset synchronizer: asserts as soon as KEY[0] is pressed, releases on a
    // clock edge so every flop leaves reset in the same cycle. Powers up
    // asserted so the CPU starts cleanly after the FPGA is configured.
    // ------------------------------------------------------------------------
    logic [1:0] rst_sync = 2'b11;
    logic       reset;

    always @(posedge CLOCK_50, negedge KEY[0])
        if (!KEY[0]) rst_sync <= 2'b11;
        else         rst_sync <= {rst_sync[0], 1'b0};

    assign reset = rst_sync[1];

    // ------------------------------------------------------------------------
    // Switch synchronizer: SW is asynchronous to CLOCK_50
    // ------------------------------------------------------------------------
    logic [9:0] sw_meta, sw_sync;

    always_ff @(posedge CLOCK_50) begin
        sw_meta <= SW;
        sw_sync <= sw_meta;
    end

    // ------------------------------------------------------------------------
    // CPU (small memories while they are still asynchronous-read; see README)
    // ------------------------------------------------------------------------
    logic [31:0] io_out;

    riscv_top #(
        .IMEM_INIT_F (IMEM_INIT_F),
        .IMEM_DEPTH  (256),
        .DMEM_DEPTH  (256)
    ) cpu (
        .clk    (CLOCK_50),
        .reset  (reset),
        .io_out (io_out),
        .io_in  ({22'b0, sw_sync})
    );

    // ------------------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------------------
    assign LEDR = io_out[9:0];

    hex7seg h0 (.hex(io_out[3:0]),   .seg(HEX0));
    hex7seg h1 (.hex(io_out[7:4]),   .seg(HEX1));
    hex7seg h2 (.hex(io_out[11:8]),  .seg(HEX2));
    hex7seg h3 (.hex(io_out[15:12]), .seg(HEX3));
    hex7seg h4 (.hex(io_out[19:16]), .seg(HEX4));
    hex7seg h5 (.hex(io_out[23:20]), .seg(HEX5));

endmodule
