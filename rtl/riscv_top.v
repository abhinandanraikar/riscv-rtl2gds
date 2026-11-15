// riscv_top.v - simulation top: core + instruction ROM + data RAM
// For the ASIC flow the top module is riscv_core, not this file.
`default_nettype none
module riscv_top #(
    parameter INIT_FILE = ""
) (
    input  wire clk,
    input  wire rst_n
);
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_we, dmem_re;

    riscv_core u_core (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata));

    instruction_memory #(.INIT_FILE(INIT_FILE)) u_imem (
        .addr(imem_addr), .rdata(imem_rdata));

    data_memory u_dmem (
        .clk(clk), .addr(dmem_addr), .wdata(dmem_wdata),
        .wstrb(dmem_wstrb), .rdata(dmem_rdata));
endmodule
`default_nettype wire
