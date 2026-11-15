// data_memory.v - simulation-only RAM model (never synthesised)
// Byte write strobes, synchronous write, combinational read.
`default_nettype none
module data_memory #(
    parameter AW = 10                      // 2^AW words = 4 KB
) (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:(1<<AW)-1];
    wire [AW-1:0] idx = addr[AW+1:2];
    integer i;
    initial begin
        for (i = 0; i < (1<<AW); i = i + 1)
            mem[i] = 32'h0;
    end
    always @(posedge clk) begin
        if (wstrb[0]) mem[idx][7:0]   <= wdata[7:0];
        if (wstrb[1]) mem[idx][15:8]  <= wdata[15:8];
        if (wstrb[2]) mem[idx][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[idx][31:24] <= wdata[31:24];
    end
    assign rdata = mem[idx];
endmodule
`default_nettype wire
