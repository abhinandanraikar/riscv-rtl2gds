// register_file.v - 32 x 32-bit registers, x0 hard-wired to zero
// Two combinational read ports, one synchronous write port.
// Internal bypass: a register being written this cycle is readable this cycle
// (this covers the WB -> ID dependency without an extra forwarding path).
`default_nettype none
module register_file (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] regs [1:31];

    always @(posedge clk) begin
        if (we && rd != 5'd0)
            regs[rd] <= wd;
    end

    assign rd1 = (rs1 == 5'd0)       ? 32'h0 :
                 (we && rd == rs1)   ? wd    : regs[rs1];
    assign rd2 = (rs2 == 5'd0)       ? 32'h0 :
                 (we && rd == rs2)   ? wd    : regs[rs2];
endmodule
`default_nettype wire
