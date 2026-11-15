// forwarding_unit.v - selects the newest value of rs1/rs2 for the EX stage
//   2'b00 = value read in ID (from ID/EX register)
//   2'b10 = result of the instruction now in MEM (EX/MEM register)
//   2'b01 = value being written back now (MEM/WB register)
`default_nettype none
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] mem_rd,
    input  wire       mem_reg_write,
    input  wire [4:0] wb_rd,
    input  wire       wb_reg_write,
    output reg  [1:0] fwd_a,
    output reg  [1:0] fwd_b
);
    always @(*) begin
        fwd_a = 2'b00;
        fwd_b = 2'b00;
        // MEM has priority over WB because it holds the more recent result
        if (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs1)      fwd_a = 2'b10;
        else if (wb_reg_write && wb_rd != 5'd0 && wb_rd == ex_rs1)    fwd_a = 2'b01;

        if (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs2)      fwd_b = 2'b10;
        else if (wb_reg_write && wb_rd != 5'd0 && wb_rd == ex_rs2)    fwd_b = 2'b01;
    end
endmodule
`default_nettype wire
