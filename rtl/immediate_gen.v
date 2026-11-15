// immediate_gen.v - builds the sign-extended immediate for each format
`default_nettype none
module immediate_gen (
    input  wire [31:7] instr,      // opcode bits [6:0] are not needed here
    input  wire [2:0]  imm_sel,
    output reg  [31:0] imm
);
    localparam IMM_I = 3'd0, IMM_S = 3'd1, IMM_B = 3'd2, IMM_U = 3'd3, IMM_J = 3'd4;

    always @(*) begin
        case (imm_sel)
            IMM_I:   imm = {{20{instr[31]}}, instr[31:20]};
            IMM_S:   imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B:   imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            IMM_U:   imm = {instr[31:12], 12'b0};
            IMM_J:   imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm = 32'h0;
        endcase
    end
endmodule
`default_nettype wire
