// riscv_tb.v - self-checking testbench for riscv_top
// The program reports through a store to address 0xFFFFFFFC (tohost):
//   value 1         -> PASS
//   any other value -> FAIL, the value is the number of the failing check
// Options:  +vcd              write results/sim/riscv_tb.vcd
//           +regdump=<file>   write x1..x31 to <file> when the program ends
`timescale 1ns/1ps
`default_nettype none
module riscv_tb;
    parameter INIT_FILE  = "sw/build/test_all.hex";
    parameter MAX_CYCLES = 200000;
    localparam [31:0] TOHOST = 32'hFFFF_FFFC;

    reg clk   = 1'b0;
    reg rst_n = 1'b0;

    riscv_top #(.INIT_FILE(INIT_FILE)) dut (.clk(clk), .rst_n(rst_n));

    always #5 clk = ~clk;                       // 10 ns period

    integer        cycles = 0;
    integer        i, fd;
    reg [1023:0]   dumpname;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("results/sim/riscv_tb.vcd");
            $dumpvars(0, riscv_tb);
        end
        repeat (4) @(posedge clk);              // hold reset for four clock edges
        @(negedge clk) rst_n = 1'b1;            // release it away from the active edge
    end

    task dump_regs;
        begin
            if ($value$plusargs("regdump=%s", dumpname)) begin
                fd = $fopen(dumpname, "w");
                for (i = 1; i < 32; i = i + 1)
                    $fdisplay(fd, "%h", dut.u_core.u_rf.regs[i]);
                $fclose(fd);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) cycles <= cycles + 1;

        if (rst_n && dut.dmem_we && dut.dmem_addr == TOHOST) begin
            if (dut.dmem_wdata == 32'd1)
                $display("PASS  %0s  (%0d cycles)", INIT_FILE, cycles);
            else
                $display("FAIL  %0s  check %0d  (%0d cycles)", INIT_FILE, dut.dmem_wdata, cycles);
            dump_regs;
            $finish;
        end

        if (cycles > MAX_CYCLES) begin
            $display("FAIL  %0s  timeout, pc = %h", INIT_FILE, dut.imem_addr);
            $finish;
        end
    end
endmodule
`default_nettype wire
