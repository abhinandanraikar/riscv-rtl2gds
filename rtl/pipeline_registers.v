// pipeline_registers.v - one generic pipeline register, instantiated four
// times in riscv_core as IF/ID, ID/EX, EX/MEM and MEM/WB.
//   en    = 0 : hold the current value (stall)
//   flush = 1 : load FLUSH_VAL (a bubble); has priority over en
`default_nettype none
module pipe_reg #(
    parameter         W         = 32,
    parameter [W-1:0] FLUSH_VAL = {W{1'b0}}
) (
    input  wire         clk,
    input  wire         rst_n,    // synchronous reset, active low
    input  wire         en,
    input  wire         flush,
    input  wire [W-1:0] d,
    output reg  [W-1:0] q
);
    always @(posedge clk) begin
        if (!rst_n || flush) q <= FLUSH_VAL;
        else if (en)         q <= d;
    end
endmodule
`default_nettype wire
