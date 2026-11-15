// hazard_unit.v - load-use stall and branch/jump flush control
`default_nettype none
module hazard_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire [4:0] ex_rd,
    input  wire       ex_mem_read,    // instruction in EX is a load
    input  wire       ex_take,        // branch/jump taken in EX
    output wire       pc_en,
    output wire       if_id_en,
    output wire       if_id_flush,
    output wire       id_ex_flush
);
    // Load-use hazard: the instruction in ID needs a value that the load in EX
    // will only have after MEM. Hold PC and IF/ID for one cycle, insert a bubble.
    wire stall = ex_mem_read && (ex_rd != 5'd0) &&
                 ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    assign pc_en       = ~stall | ex_take;
    assign if_id_en    = ~stall;
    assign if_id_flush = ex_take;            // kill instruction in IF
    assign id_ex_flush = ex_take | stall;    // kill instruction in ID / bubble
endmodule
`default_nettype wire
