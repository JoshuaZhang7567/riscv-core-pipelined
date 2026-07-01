/*
Data Memory Module:
- Can write or read data with RAM.
- works with following memory size/type per instruction:
        - byte (b)
        - half word (h)
        - word (w)
        - unsigned byte (bu)
        - unsigned half word (hu)
- Part of the following instructions:
    - lb
    - lh
    - lw
    - lbu
    - lhu

    - sb
    - sh
    - sw
*/
import riscv_pkg::*;

module dmem
#(
    parameter int unsigned DEPTH = 1024    // 1024 words (4 KiB default), override at instantiation
)
(
    // inputs
    input logic [XLEN-1:0] write_data,
    input logic [XLEN-1:0] addr,

    // control signals
    input logic clk,
    input logic mem_write,
    input logic mem_read,
    input mem_size_t mem_size,           // MEM_BYTE, MEM_HALF, MEM_WORD
    input logic      mem_unsigned,       // 0=sign-extend, 1=zero-extend (reads only)

    output logic [XLEN-1:0] read_data
);
    // declare ram
    logic [31:0] ram [0:DEPTH-1];

    // Drop byte-select bits [1:0] to get word index
    localparam int WORD_ADDR_W = $clog2(DEPTH);
    logic [WORD_ADDR_W-1:0] word_addr;
    assign word_addr = addr[WORD_ADDR_W+1:2];

    // write data logic
    always_ff @(posedge clk) begin
        if(mem_write) begin
            case (mem_size)
                MEM_BYTE: begin
                    case (addr[1:0])
                        2'b00: ram[word_addr][7:0] <= write_data[7:0];
                        2'b01: ram[word_addr][15:8] <= write_data[7:0];
                        2'b10: ram[word_addr][23:16] <= write_data[7:0];
                        2'b11: ram[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                MEM_HALF: begin
                    case (addr[1])
                        1'b0: ram[word_addr][15:0] <= write_data[15:0];
                        1'b1: ram[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                MEM_WORD: ram[word_addr] <= write_data;
                default: ;
            endcase
        end
    end

    // read data logic
    always_comb begin
        if(mem_read) begin
            case (mem_size)
                MEM_BYTE: begin
                    case (addr[1:0])
                        2'b00: read_data = mem_unsigned ? {24'b0, ram[word_addr][7:0]}   : {{24{ram[word_addr][7]}},  ram[word_addr][7:0]};
                        2'b01: read_data = mem_unsigned ? {24'b0, ram[word_addr][15:8]}  : {{24{ram[word_addr][15]}}, ram[word_addr][15:8]};
                        2'b10: read_data = mem_unsigned ? {24'b0, ram[word_addr][23:16]} : {{24{ram[word_addr][23]}}, ram[word_addr][23:16]};
                        2'b11: read_data = mem_unsigned ? {24'b0, ram[word_addr][31:24]} : {{24{ram[word_addr][31]}}, ram[word_addr][31:24]};
                    endcase
                end
                MEM_HALF: begin
                    case (addr[1])
                        1'b0: read_data = mem_unsigned ? {16'b0, ram[word_addr][15:0]}  : {{16{ram[word_addr][15]}}, ram[word_addr][15:0]};
                        1'b1: read_data = mem_unsigned ? {16'b0, ram[word_addr][31:16]} : {{16{ram[word_addr][31]}}, ram[word_addr][31:16]};
                    endcase
                end
                MEM_WORD: begin
                    read_data = ram[word_addr];
                end
                default: read_data = '0;
            endcase
        end
        else read_data = '0; // output zero (turn it off) when not reading (mem_read is 0)
    end

endmodule