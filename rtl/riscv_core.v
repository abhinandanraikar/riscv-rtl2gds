// riscv_core.v - RV32I 5-stage pipelined core (IF, ID, EX, MEM, WB)
// THIS is the ASIC top module. Memories are outside the core and are reached
// through the imem_* / dmem_* ports.
`default_nettype none
module riscv_core #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    // instruction memory (combinational read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    // data memory (combinational read, synchronous byte-strobed write)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata
);
    localparam [31:0] NOP = 32'h0000_0013;      // addi x0, x0, 0

    // ------------------------------------------------------------------ IF
    wire [31:0] if_pc, if_pc_plus4, pc_next;
    wire        pc_en, if_id_en, if_id_flush, id_ex_flush;
    wire        ex_take;                 // branch/jump taken, decided in EX
    wire [31:0] ex_target;

    assign if_pc_plus4 = if_pc + 32'd4;
    assign pc_next     = ex_take ? ex_target : if_pc_plus4;
    assign imem_addr   = if_pc;

    program_counter #(.RESET_PC(RESET_PC)) u_pc (
        .clk(clk), .rst_n(rst_n), .en(pc_en), .pc_next(pc_next), .pc(if_pc));

    // ---------------------------------------------------------------- IF/ID
    wire [31:0] id_pc, id_instr;
    pipe_reg #(.W(64), .FLUSH_VAL({32'h0, NOP})) u_if_id (
        .clk(clk), .rst_n(rst_n), .en(if_id_en), .flush(if_id_flush),
        .d({if_pc, imem_rdata}), .q({id_pc, id_instr}));

    // ------------------------------------------------------------------ ID
    wire [4:0]  id_rs1 = id_instr[19:15];
    wire [4:0]  id_rs2 = id_instr[24:20];
    wire [4:0]  id_rd  = id_instr[11:7];
    wire [2:0]  id_funct3 = id_instr[14:12];

    wire        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    wire        id_branch, id_jal, id_jalr, id_alu_src_a, id_alu_src_b;
    wire [3:0]  id_alu_op;
    wire [2:0]  id_imm_sel;
    wire [31:0] id_rd1, id_rd2, id_imm;

    control_unit u_ctrl (
        .opcode(id_instr[6:0]), .funct3(id_funct3), .funct7b5(id_instr[30]),
        .reg_write(id_reg_write), .mem_read(id_mem_read), .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg), .branch(id_branch), .jal(id_jal), .jalr(id_jalr),
        .alu_src_a(id_alu_src_a), .alu_src_b(id_alu_src_b),
        .alu_op(id_alu_op), .imm_sel(id_imm_sel));

    immediate_gen u_imm (.instr(id_instr[31:7]), .imm_sel(id_imm_sel), .imm(id_imm));

    // write-back signals (driven from the WB stage below)
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    register_file u_rf (
        .clk(clk), .we(wb_reg_write), .rs1(id_rs1), .rs2(id_rs2),
        .rd(wb_rd), .wd(wb_data), .rd1(id_rd1), .rd2(id_rd2));

    // ---------------------------------------------------------------- ID/EX
    wire [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    wire        ex_branch, ex_jal, ex_jalr, ex_alu_src_a, ex_alu_src_b;
    wire [3:0]  ex_alu_op;

    pipe_reg #(.W(159)) u_id_ex (
        .clk(clk), .rst_n(rst_n), .en(1'b1), .flush(id_ex_flush),
        .d({id_pc, id_rd1, id_rd2, id_imm, id_rs1, id_rs2, id_rd, id_funct3,
            id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg,
            id_branch, id_jal, id_jalr, id_alu_src_a, id_alu_src_b, id_alu_op}),
        .q({ex_pc, ex_rd1, ex_rd2, ex_imm, ex_rs1, ex_rs2, ex_rd, ex_funct3,
            ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg,
            ex_branch, ex_jal, ex_jalr, ex_alu_src_a, ex_alu_src_b, ex_alu_op}));

    // ------------------------------------------------------------------ EX
    wire [1:0]  fwd_a, fwd_b;
    wire [31:0] mem_result;                 // EX/MEM result (declared below)
    wire [4:0]  mem_rd;
    wire        mem_reg_write;

    forwarding_unit u_fwd (
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .mem_rd(mem_rd), .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd),   .wb_reg_write(wb_reg_write),
        .fwd_a(fwd_a), .fwd_b(fwd_b));

    wire [31:0] ex_fwd_a = (fwd_a == 2'b10) ? mem_result :
                           (fwd_a == 2'b01) ? wb_data    : ex_rd1;
    wire [31:0] ex_fwd_b = (fwd_b == 2'b10) ? mem_result :
                           (fwd_b == 2'b01) ? wb_data    : ex_rd2;

    wire [31:0] alu_a = ex_alu_src_a ? ex_pc  : ex_fwd_a;
    wire [31:0] alu_b = ex_alu_src_b ? ex_imm : ex_fwd_b;
    wire [31:0] alu_result;

    alu u_alu (.a(alu_a), .b(alu_b), .op(ex_alu_op), .y(alu_result));

    // branch decision: compare the forwarded operands, condition from funct3
    reg ex_cond;
    always @(*) begin
        case (ex_funct3)
            3'b000:  ex_cond = (ex_fwd_a == ex_fwd_b);                       // BEQ
            3'b001:  ex_cond = (ex_fwd_a != ex_fwd_b);                       // BNE
            3'b100:  ex_cond = ($signed(ex_fwd_a) <  $signed(ex_fwd_b));     // BLT
            3'b101:  ex_cond = ($signed(ex_fwd_a) >= $signed(ex_fwd_b));     // BGE
            3'b110:  ex_cond = (ex_fwd_a <  ex_fwd_b);                       // BLTU
            3'b111:  ex_cond = (ex_fwd_a >= ex_fwd_b);                       // BGEU
            default: ex_cond = 1'b0;
        endcase
    end
    assign ex_take = (ex_branch & ex_cond) | ex_jal | ex_jalr;

    wire [31:0] ex_pc_plus4 = ex_pc + 32'd4;
    wire [31:0] ex_pc_imm   = ex_pc + ex_imm;
    assign ex_target = ex_jalr ? {alu_result[31:1], 1'b0} : ex_pc_imm;

    // JAL/JALR write the return address (PC+4) into rd
    wire [31:0] ex_result = (ex_jal | ex_jalr) ? ex_pc_plus4 : alu_result;

    hazard_unit u_haz (
        .id_rs1(id_rs1), .id_rs2(id_rs2), .ex_rd(ex_rd),
        .ex_mem_read(ex_mem_read), .ex_take(ex_take),
        .pc_en(pc_en), .if_id_en(if_id_en),
        .if_id_flush(if_id_flush), .id_ex_flush(id_ex_flush));

    // --------------------------------------------------------------- EX/MEM
    wire [31:0] mem_store_data;
    wire [2:0]  mem_funct3;
    wire        mem_mem_read, mem_mem_write, mem_mem_to_reg;

    pipe_reg #(.W(76)) u_ex_mem (
        .clk(clk), .rst_n(rst_n), .en(1'b1), .flush(1'b0),
        .d({ex_result, ex_fwd_b, ex_rd, ex_funct3,
            ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg}),
        .q({mem_result, mem_store_data, mem_rd, mem_funct3,
            mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg}));

    // ----------------------------------------------------------------- MEM
    wire [31:0] load_data;
    wire [3:0]  lsu_wstrb;

    load_store_unit u_lsu (
        .funct3(mem_funct3), .addr_lsb(mem_result[1:0]),
        .store_data(mem_store_data), .mem_rdata(dmem_rdata),
        .mem_wdata(dmem_wdata), .mem_wstrb(lsu_wstrb), .load_data(load_data));

    assign dmem_addr  = mem_result;
    assign dmem_wstrb = mem_mem_write ? lsu_wstrb : 4'b0000;
    assign dmem_we    = mem_mem_write;
    assign dmem_re    = mem_mem_read;

    // --------------------------------------------------------------- MEM/WB
    wire [31:0] wb_result, wb_load;
    wire        wb_mem_to_reg;

    pipe_reg #(.W(71)) u_mem_wb (
        .clk(clk), .rst_n(rst_n), .en(1'b1), .flush(1'b0),
        .d({mem_result, load_data, mem_rd, mem_reg_write, mem_mem_to_reg}),
        .q({wb_result,  wb_load,   wb_rd,  wb_reg_write,  wb_mem_to_reg}));

    // ------------------------------------------------------------------ WB
    assign wb_data = wb_mem_to_reg ? wb_load : wb_result;
endmodule
`default_nettype wire
