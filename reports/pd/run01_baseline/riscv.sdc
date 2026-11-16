# riscv.sdc - timing constraints for riscv_core (SKY130 HD, typical corner)
current_design riscv_core

set clk_name    core_clock
set clk_port    [get_ports clk]
set clk_period  10.0          ;# ns -> 100 MHz. Tighten or relax after STA.
set io_pct      0.20          ;# share of the period used outside the block

# --- clock ---------------------------------------------------------------
create_clock -name $clk_name -period $clk_period $clk_port
set_clock_uncertainty 0.25 [get_clocks $clk_name]   ;# jitter + skew margin
set_clock_transition  0.15 [get_clocks $clk_name]   ;# ideal-clock slew, pre-CTS

# --- inputs / outputs ----------------------------------------------------
set non_clock_inputs [all_inputs -no_clocks]

set_input_delay  [expr {$clk_period * $io_pct}] -clock $clk_name $non_clock_inputs
set_output_delay [expr {$clk_period * $io_pct}] -clock $clk_name [all_outputs]

# drive strength of whatever feeds the inputs, load on every output
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $non_clock_inputs
set_load 0.05 [all_outputs]                          ;# pF
