# synth_sky130.tcl - standalone Yosys synthesis mapped to SKY130 HD cells
# Run from the project root:
#   LIB=<path>/sky130_fd_sc_hd__tt_025C_1v80.lib yosys -c scripts/synth_sky130.tcl
# (make synth-sky130 sets LIB for you from ORFS_DIR)
yosys -import

set lib $::env(LIB)
set top riscv_core
set rtl {
    rtl/riscv_core.v rtl/program_counter.v rtl/pipeline_registers.v
    rtl/control_unit.v rtl/immediate_gen.v rtl/register_file.v
    rtl/alu.v rtl/hazard_unit.v rtl/forwarding_unit.v rtl/load_store_unit.v
}

# cell pin directions, so that 'check' understands the mapped netlist
read_liberty -lib -ignore_miss_dir -setattr blackbox $lib

foreach f $rtl { read_verilog $f }
hierarchy -check -top $top

synth -top $top -flatten             ;# generic synthesis, one flat module
opt -purge

dfflibmap -liberty $lib              ;# flip-flops -> SKY130 flops
abc -liberty $lib                    ;# combinational logic -> SKY130 gates
hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
opt_clean -purge

check
tee -o reports/synth/sky130_stat.rpt stat -liberty $lib
write_verilog -noattr -noexpr -nohex results/synth/riscv_core_sky130.v
