// control_unit.v - main decoder: opcode/funct3/funct7 -> control signals
`default_nettype none
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7b5,      // instr[30]
    output reg        reg_write,     // write rd in WB
    output reg        mem_read,      // load
    output reg        mem_write,     // store
    output reg        mem_to_reg,    // WB data: 1 = memory, 0 = EX result
    output reg        branch,        // conditional branch
    output reg        jal,
    output reg        jalr,
    output reg        alu_src_a,     // 0 = rs1, 1 = PC
    output reg        alu_src_b,     // 0 = rs2, 1 = immediate
    output reg  [3:0] alu_op,
    output reg  [2:0] imm_sel
);
    localparam OP_R = 7'b0110011, OP_I = 7'b0010011, OP_LOAD = 7'b0000011,
               OP_STORE = 7'b0100011, OP_BRANCH = 7'b1100011, OP_JAL = 7'b1101111,
               OP_JALR = 7'b1100111, OP_LUI = 7'b0110111, OP_AUIPC = 7'b0010111;

    localparam ALU_ADD  = 4'd0, ALU_SUB  = 4'd1, ALU_SLL = 4'd2, ALU_SLT = 4'd3,
               ALU_SLTU = 4'd4, ALU_XOR  = 4'd5, ALU_SRL = 4'd6, ALU_SRA = 4'd7,
               ALU_OR   = 4'd8, ALU_AND  = 4'd9, ALU_PASSB = 4'd10;

    localparam IMM_I = 3'd0, IMM_S = 3'd1, IMM_B = 3'd2, IMM_U = 3'd3, IMM_J = 3'd4;

    // ALU operation for R-type and I-type arithmetic, from funct3/funct7
    reg [3:0] arith_op;
    always @(*) begin
        case (funct3)
            3'b000:  arith_op = (opcode == OP_R && funct7b5) ? ALU_SUB : ALU_ADD;
            3'b001:  arith_op = ALU_SLL;
            3'b010:  arith_op = ALU_SLT;
            3'b011:  arith_op = ALU_SLTU;
            3'b100:  arith_op = ALU_XOR;
            3'b101:  arith_op = funct7b5 ? ALU_SRA : ALU_SRL;
            3'b110:  arith_op = ALU_OR;
            default: arith_op = ALU_AND;
        endcase
    end

    always @(*) begin
        // safe defaults: an unknown opcode behaves like a NOP
        reg_write = 1'b0; mem_read  = 1'b0; mem_write = 1'b0; mem_to_reg = 1'b0;
        branch    = 1'b0; jal       = 1'b0; jalr      = 1'b0;
        alu_src_a = 1'b0; alu_src_b = 1'b0;
        alu_op    = ALU_ADD;
        imm_sel   = IMM_I;
        case (opcode)
            OP_R:      begin reg_write = 1'b1; alu_op = arith_op; end
            OP_I:      begin reg_write = 1'b1; alu_src_b = 1'b1; alu_op = arith_op; end
            OP_LOAD:   begin reg_write = 1'b1; mem_read = 1'b1; mem_to_reg = 1'b1;
                             alu_src_b = 1'b1; end
            OP_STORE:  begin mem_write = 1'b1; alu_src_b = 1'b1; imm_sel = IMM_S; end
            OP_BRANCH: begin branch = 1'b1; imm_sel = IMM_B; end
            OP_JAL:    begin reg_write = 1'b1; jal = 1'b1; imm_sel = IMM_J; end
            OP_JALR:   begin reg_write = 1'b1; jalr = 1'b1; alu_src_b = 1'b1; end
            OP_LUI:    begin reg_write = 1'b1; alu_src_b = 1'b1; alu_op = ALU_PASSB;
                             imm_sel = IMM_U; end
            OP_AUIPC:  begin reg_write = 1'b1; alu_src_a = 1'b1; alu_src_b = 1'b1;
                             imm_sel = IMM_U; end
            default:   ;
        endcase
    end
endmodule
`default_nettype wire
