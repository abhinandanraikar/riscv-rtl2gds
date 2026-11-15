// program_counter.v - PC register with enable (stall) and synchronous reset
`default_nettype none
module program_counter #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,     // synchronous reset, active low
    input  wire        en,        // 0 = hold the PC (pipeline stall)
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (!rst_n)  pc <= RESET_PC;
        else if (en) pc <= pc_next;
    end
endmodule
`default_nettype wire
