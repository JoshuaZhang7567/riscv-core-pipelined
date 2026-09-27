// Board-level smoke test: runs fpga/de1soc/led_counter.hex on de1soc_top and
// checks that the LEDs count up by one, HEX0 shows the count, and the delay
// scales with the switches (SW read through memory-mapped I/O).

`timescale 1ns / 1ps

module tb_de1soc_top;

    logic       CLOCK_50 = 0;
    logic [3:0] KEY = 4'hF;
    logic [9:0] SW  = '0;
    logic [9:0] LEDR;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    always #10 CLOCK_50 = ~CLOCK_50;   // 50 MHz

    de1soc_top #(.IMEM_INIT_F("fpga/de1soc/led_counter.hex")) dut (.*);

    integer fail_count = 0;
    integer t_prev;

    // Wait for the next LED change (with timeout), return the cycles it took
    task automatic next_count(output integer cycles);
        logic [9:0] prev;
        prev   = LEDR;
        cycles = 0;
        while (LEDR == prev && cycles < 1_000_000) begin
            @(posedge CLOCK_50);
            cycles++;
        end
        if (LEDR != prev + 10'd1) begin
            $display("  [FAIL] LEDR went %0d -> %0d (expected +1)", prev, LEDR);
            fail_count++;
        end
    endtask

    integer c, period_sw0, period_sw1;

    initial begin
        // Press and release reset
        KEY[0] = 0;
        repeat (5) @(posedge CLOCK_50);
        KEY[0] = 1;

        // First store writes 0; then count 1, 2, 3 with SW = 0
        next_count(c);
        next_count(c);
        next_count(period_sw0);
        $display("  SW=0: %0d cycles per count", period_sw0);

        if (HEX0 !== ~7'b1001111) begin   // "3"
            $display("  [FAIL] HEX0 = %b, expected digit 3", HEX0);
            fail_count++;
        end

        // SW = 1 doubles the delay loop: (SW + 1) << 14 iterations
        SW = 10'd1;
        next_count(c);                     // let the current delay finish
        next_count(period_sw1);
        $display("  SW=1: %0d cycles per count", period_sw1);
        if (period_sw1 < period_sw0 * 19 / 10 || period_sw1 > period_sw0 * 21 / 10) begin
            $display("  [FAIL] expected SW=1 period ~2x SW=0 period");
            fail_count++;
        end

        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL (%0d)", fail_count);
        $finish;
    end

endmodule
