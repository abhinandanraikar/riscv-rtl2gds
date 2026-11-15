# sta.tcl - post-route static timing analysis with OpenSTA
# Inputs come from the finished ORFS run (netlist, SDC, extracted parasitics).
# Run with:  make sta
# (OpenSTA is built into OpenROAD, so the openroad binary runs this script;
#  the stand-alone 'sta' binary accepts the same commands.)
set lib $::env(LIB)
set run $::env(RUN)
set rpt reports/sta
file mkdir $rpt

read_liberty $lib
if { [info commands read_db] ne "" } {
    # running inside OpenROAD: load the final database (netlist + layout)
    read_db $run/6_final.odb
} else {
    # running in stand-alone OpenSTA: load the final Verilog netlist
    read_verilog $run/6_final.v
    link_design riscv_core
}
read_sdc  $run/6_final.sdc
read_spef $run/6_final.spef
set_propagated_clock [all_clocks]          ;# use the real clock tree delays

# ---- summary ----
report_tns
report_wns
report_worst_slack -max
report_worst_slack -min

# ---- detailed reports to files ----
report_checks -path_delay max -group_path_count 10 -format full_clock_expanded \
    -fields {slew cap input_pins fanout} > $rpt/setup_paths.rpt
report_checks -path_delay min -group_path_count 10 -format full_clock_expanded \
    -fields {slew cap input_pins fanout} > $rpt/hold_paths.rpt
report_check_types -max_slew -max_capacitance -max_fanout -violators > $rpt/drv_violations.rpt
report_clock_skew        > $rpt/clock_skew.rpt
report_clock_min_period  > $rpt/min_period.rpt
report_power             > $rpt/power.rpt
puts "Detailed reports written to $rpt/"
