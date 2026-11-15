// load_store_unit.v - byte/halfword alignment for loads and stores (MEM stage)
`default_nettype none
module load_store_unit (
    input  wire [2:0]  funct3,      // 000 B, 001 H, 010 W, 100 BU, 101 HU
    input  wire [1:0]  addr_lsb,
    input  wire [31:0] store_data,  // rs2 value
    input  wire [31:0] mem_rdata,   // raw word from memory
    output reg  [31:0] mem_wdata,   // aligned store data
    output reg  [3:0]  mem_wstrb,   // byte enables
    output reg  [31:0] load_data    // aligned + extended load data
);
    // move the addressed byte / halfword down to bit 0
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] shifted = mem_rdata >> {addr_lsb, 3'b000};
    /* verilator lint_on UNUSEDSIGNAL */

    always @(*) begin
        case (funct3[1:0])
            2'b00:   begin mem_wdata = {4{store_data[7:0]}};
                           mem_wstrb = 4'b0001 << addr_lsb; end
            2'b01:   begin mem_wdata = {2{store_data[15:0]}};
                           mem_wstrb = addr_lsb[1] ? 4'b1100 : 4'b0011; end
            default: begin mem_wdata = store_data;
                           mem_wstrb = 4'b1111; end
        endcase
        case (funct3)
            3'b000:  load_data = {{24{shifted[7]}},  shifted[7:0]};    // LB
            3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};   // LH
            3'b100:  load_data = {24'b0, shifted[7:0]};                // LBU
            3'b101:  load_data = {16'b0, shifted[15:0]};               // LHU
            default: load_data = mem_rdata;                            // LW
        endcase
    end
endmodule
`default_nettype wire
