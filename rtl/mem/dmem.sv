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
    // RAM as 4 byte lanes per word: the byte-enable form Quartus infers as RAM.
    // ram[i] still reads as a full 32-bit word.
    logic [3:0][7:0] ram [0:DEPTH-1];

    // Drop byte-select bits [1:0] to get word index
    localparam int WORD_ADDR_W = $clog2(DEPTH);
    logic [WORD_ADDR_W-1:0] word_addr;
    assign word_addr = addr[WORD_ADDR_W+1:2];

    // Byte enables + store data replicated onto the lanes it may land in
    logic [3:0]  byte_en;
    logic [31:0] lane_data;

    always_comb begin
        case (mem_size)
            MEM_BYTE: begin
                byte_en   = 4'b0001 << addr[1:0];
                lane_data = {4{write_data[7:0]}};
            end
            MEM_HALF: begin
                byte_en   = addr[1] ? 4'b1100 : 4'b0011;
                lane_data = {2{write_data[15:0]}};
            end
            MEM_WORD: begin
                byte_en   = 4'b1111;
                lane_data = write_data;
            end
            default: begin
                byte_en   = 4'b0000;
                lane_data = write_data;
            end
        endcase
    end

    // write data logic
    always_ff @(posedge clk) begin
        if (mem_write) begin
            for (int i = 0; i < 4; i++)
                if (byte_en[i]) ram[word_addr][i] <= lane_data[8*i +: 8];
        end
    end

    // read data logic: pick the addressed byte/half, then sign- or zero-extend
    logic [31:0] word;
    logic [7:0]  rd_byte;
    logic [15:0] rd_half;
    assign word    = ram[word_addr];
    assign rd_byte = word[8*addr[1:0] +: 8];
    assign rd_half = addr[1] ? word[31:16] : word[15:0];

    always_comb begin
        if (mem_read) begin
            case (mem_size)
                MEM_BYTE: read_data = mem_unsigned ? {24'b0, rd_byte} : {{24{rd_byte[7]}},  rd_byte};
                MEM_HALF: read_data = mem_unsigned ? {16'b0, rd_half} : {{16{rd_half[15]}}, rd_half};
                MEM_WORD: read_data = word;
                default:  read_data = '0;
            endcase
        end
        else read_data = '0; // output zero (turn it off) when not reading (mem_read is 0)
    end

endmodule