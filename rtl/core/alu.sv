import riscv_pkg::*;

module alu (
    input  logic [XLEN-1:0]       a,            // Operand A (rs1 or PC)
    input  logic [XLEN-1:0]       b,            // Operand B (rs2 or ImmExt)
    input  alu_control_t          alu_control,  // Operation select

    output logic [XLEN-1:0]       result,       // ALU result
    output logic                  zero          // result == 0
);

  logic [XLEN-1:0] sum;
  logic            cout;

  // Shared add/sub datapath
  always_comb begin
    if (alu_control == ALU_SUB)
      {cout, sum} = {1'b0, a} + {1'b0, ~b} + 33'd1;
    else
      {cout, sum} = {1'b0, a} + {1'b0,  b};
  end

  always_comb begin
    unique case (alu_control)
      ALU_ADD:    result = sum;
      ALU_SUB:    result = sum;
      ALU_AND:    result = a & b;
      ALU_OR:     result = a | b;
      ALU_XOR:    result = a ^ b;
      ALU_SLT:    result = {{(XLEN-1){1'b0}}, ($signed(a) < $signed(b))};
      ALU_SLTU:   result = {{(XLEN-1){1'b0}}, (a < b)};
      ALU_SLL:    result = a << b[4:0];
      ALU_SRL:    result = a >> b[4:0];
      ALU_SRA:    result = $signed(a) >>> b[4:0];
      ALU_PASS_B: result = b;
      default:    result = '0;
    endcase
  end

  assign zero = (result == '0);

endmodule
