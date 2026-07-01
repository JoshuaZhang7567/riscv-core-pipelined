// Universal testbench — runs any RV32I test program via command-line args.
//   +HEX_FILE=<path>    — program hex file for IMEM
//   +EXPECTED=<path>     — expected results file

`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_riscv_universal;

    // Clock
    logic clk, reset;
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    riscv_top #(
        .IMEM_INIT_F (""),
        .IMEM_DEPTH  (1024),
        .DMEM_DEPTH  (1024)
    ) dut (
        .clk   (clk),
        .reset (reset)
    );

    // Scoreboard
    integer pass_count = 0;
    integer fail_count = 0;

    // Check register equals expected value
    task automatic check_reg_eq(input int addr, input [31:0] expected);
        if (dut.rf.rf[addr] === expected) begin
            $display("  [PASS] x%-2d = 0x%08h (%0d)", addr, expected, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] x%-2d = 0x%08h  (expected 0x%08h)",
                     addr, dut.rf.rf[addr], expected);
            fail_count++;
        end
    endtask

    // Check register does NOT equal a value (branch skip verification)
    task automatic check_reg_neq(input int addr, input [31:0] bad_val);
        if (dut.rf.rf[addr] !== bad_val) begin
            $display("  [PASS] x%-2d != 0x%08h (skipped)", addr, bad_val);
            pass_count++;
        end else begin
            $display("  [FAIL] x%-2d = 0x%08h  (should have been skipped!)",
                     addr, dut.rf.rf[addr]);
            fail_count++;
        end
    endtask

    // Check memory word equals expected value
    task automatic check_mem_eq(input int addr, input [31:0] expected);
        if (dut.data_mem.ram[addr] === expected) begin
            $display("  [PASS] mem[%0d] = 0x%08h (%0d)", addr, expected, expected);
            pass_count++;
        end else begin
            $display("  [FAIL] mem[%0d] = 0x%08h  (expected 0x%08h)",
                     addr, dut.data_mem.ram[addr], expected);
            fail_count++;
        end
    endtask

    // Parsing variables
    reg [128*8-1:0] hex_file;
    reg [128*8-1:0] expected_file;
    integer fd, r, num_cycles_cfg, check_type, check_addr;
    reg [31:0] check_value;

    initial begin
        $dumpfile("sim/waveforms/riscv_universal.vcd");
        $dumpvars(0, tb_riscv_universal);

        // Read command-line args
        if (!$value$plusargs("HEX_FILE=%s", hex_file)) begin
            $display("ERROR: No program specified.");
            $display("  Usage: vvp <out_file> +HEX_FILE=<path.hex> +EXPECTED=<path.expected>");
            $finish;
        end
        if (!$value$plusargs("EXPECTED=%s", expected_file)) begin
            $display("ERROR: No expected-results file specified.");
            $display("  Usage: vvp <out_file> +HEX_FILE=<path.hex> +EXPECTED=<path.expected>");
            $finish;
        end

        // Load program while CPU is held in reset
        reset = 1;
        $readmemh(hex_file, dut.instr_mem.rom);

        // Read cycle count from expected-results file
        fd = $fopen(expected_file, "r");
        if (fd == 0) begin
            $display("ERROR: Cannot open file: %0s", expected_file);
            $finish;
        end
        r = $fscanf(fd, "%d", num_cycles_cfg);
        if (r != 1) begin
            $display("ERROR: Could not read cycle count from %0s", expected_file);
            $finish;
        end

        // Release reset
        repeat(2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Run
        $display("");
        $display("Running %0s for %0d cycles...", hex_file, num_cycles_cfg);
        repeat(num_cycles_cfg) @(posedge clk);

        // Verify results
        $display("");
        $display("================================================================");
        $display("  Test Results: %0s", hex_file);
        $display("================================================================");

        while (!$feof(fd)) begin
            r = $fscanf(fd, "%d %d %h", check_type, check_addr, check_value);
            if (r == 3) begin
                case (check_type)
                    0: check_reg_eq (check_addr, check_value);
                    1: check_reg_neq(check_addr, check_value);
                    2: check_mem_eq (check_addr, check_value);
                    default: $display("  [WARN] Unknown check type: %0d", check_type);
                endcase
            end
        end

        $fclose(fd);

        // Summary
        $display("");
        $display("----------------------------------------------------------------");
        $display("  Passed: %0d   Failed: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("----------------------------------------------------------------");
        $display("");

        $finish;
    end

endmodule
