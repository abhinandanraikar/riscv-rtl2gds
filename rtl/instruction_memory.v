// instruction_memory.v - simulation-only ROM model (never synthesised)
// Word addressed, combinational read, contents loaded from a hex file.
`default_nettype none
module instruction_memory #(
    parameter AW        = 10,              // 2^AW words = 4 KB
    parameter INIT_FILE = ""
) (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:(1<<AW)-1];
    integer i;
    initial begin
        for (i = 0; i < (1<<AW); i = i + 1)
            mem[i] = 32'h0000_0013;        // NOP (addi x0, x0, 0)
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    assign rdata = mem[addr[AW+1:2]];
endmodule
`default_nettype wire
